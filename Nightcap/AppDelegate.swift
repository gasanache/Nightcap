//
//  AppDelegate.swift
//  Nightcap
//
//  This file is part of Nightcap.
//
//  Nightcap is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Nightcap is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Nightcap.
//  If not, see https://www.gnu.org/licenses/.
//

import Foundation
import NightcapKit
import os
import SwiftUI

private let logger = Logger(subsystem: Bundle.nightcapBundleIdentifier, category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {
    @AppStorage("hasShownMoveToApplicationsAlert") private var hasShownMoveToApplicationsAlert = false

    func application(_ application: NSApplication, open urls: [URL]) {
        // Test if automatic window tabbing is enabled
        // as it is disabled when ContentView appears
        if NSWindow.allowsAutomaticWindowTabbing, let url = urls.first {
            // Reopen the file after Nightcap has been opened
            // so that the `onOpenURL` handler is actually called
            NSWorkspace.shared.open(url)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The Settings toggle declares `killOnTerminate` with a default of
        // true, but `UserDefaults.bool(forKey:)` returns false for a key never
        // written — so the toggle showed ON while the terminate path and the
        // orphan sweep behaved as OFF until the user flipped it once.
        UserDefaults.standard.register(defaults: ["killOnTerminate": true])

        // Before any window is on screen, so the first frame is already in the
        // chosen appearance rather than flashing the system one first.
        AppAppearance.applyStored()

        if !hasShownMoveToApplicationsAlert, !AppDelegate.insideAppsFolder {
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                NSApp.activate(ignoringOtherApps: true)
                self.showAlertOnFirstLaunch()
                self.hasShownMoveToApplicationsAlert = true
            }
        }

        // Background cleanup of orphaned temp files from previous sessions
        Task.detached {
            await TempFileTracker.shared.cleanupOldFiles(olderThan: 24 * 60 * 60)
        }

        // Startup orphan process detection
        // Probe each known bottle's wineserver to detect processes from previous sessions
        Task {
            // Wait for bottles to load (BottleVM needs time to initialize)
            try? await Task.sleep(for: .seconds(2))
            await self.sweepOrphanProcesses()
        }
    }

    /// Kill-on-quit has to finish before the process exits. The old
    /// implementation ran the kills from `applicationWillTerminate` via
    /// `Wine.killBottle`, which wraps the work in a `Task` — the delegate
    /// returned, AppKit exited, and the task never got a turn, so the setting
    /// silently did nothing (which is why the launch-time orphan sweep exists).
    /// `.terminateLater` holds termination open until the kills complete, with
    /// a hard cap so a wedged wineserver cannot hang quit forever.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let globalKill = UserDefaults.standard.bool(forKey: "killOnTerminate")
        let toKill = BottleVM.shared.bottles.filter { bottle in
            switch bottle.settings.killOnQuit {
            case .inherit: globalKill
            case .alwaysKill: true
            case .neverKill: false
            }
        }
        guard !toKill.isEmpty else { return .terminateNow }

        Task { @MainActor in
            // Sequential with a hard deadline: killBottleAndWait itself polls
            // for at most ~2 s per bottle, and the deadline means a wedged
            // wineserver cannot hold quit hostage.
            let deadline = Date().addingTimeInterval(10)
            for bottle in toKill {
                guard Date() < deadline else {
                    logger.warning("Quit deadline reached; remaining bottles left to the orphan sweep")
                    break
                }
                logger.info("Killing bottle '\(bottle.settings.name)' on quit")
                await Wine.killBottleAndWait(bottle: bottle)
                ProcessRegistry.shared.clearRegistry(for: bottle.url)
            }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Synchronous best-effort temp file cleanup (cannot await in applicationWillTerminate)
        let trackedFiles = TempFileTracker.shared.getAllTrackedFiles()
        for (fileURL, _) in trackedFiles {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // When the user opts into the menu-bar extra, keep Nightcap running after
        // the window closes so it stays reachable from the menu bar (and Wine
        // processes keep running). Otherwise quit on last window close, as usual.
        !UserDefaults.standard.bool(forKey: "showMenuBarExtra")
    }

    private static var appUrl: URL? {
        Bundle.main.resourceURL?.deletingLastPathComponent().deletingLastPathComponent()
    }

    private static let expectedUrl = URL(fileURLWithPath: "/Applications/Nightcap.app")

    private static var insideAppsFolder: Bool {
        if let url = appUrl {
            return url.path.contains("Xcode") || url.path.contains(expectedUrl.path)
        }
        return false
    }

    @MainActor
    private func sweepOrphanProcesses() async {
        var cleanedCount = 0

        for bottle in BottleVM.shared.bottles {
            let isRunning = await Wine.isWineserverRunning(for: bottle)
            guard isRunning else { continue }

            let bottleName = bottle.settings.name
            let policy = bottle.settings.killOnQuit
            let globalKill = UserDefaults.standard.bool(forKey: "killOnTerminate")
            let shouldAutoClean: Bool = switch policy {
            case .inherit: globalKill
            case .alwaysKill: true
            case .neverKill: false
            }

            if shouldAutoClean {
                // Auto-clean orphans per kill-on-quit policy
                Wine.killBottle(bottle: bottle)
                cleanedCount += 1
                logger.info(
                    "Auto-cleaned orphan processes in bottle '\(bottleName)' (kill-on-quit policy active)"
                )
            } else {
                // Flag only -- do NOT auto-clean
                logger.info(
                    "Detected orphan Wine processes in bottle '\(bottleName)' (flagged, not auto-cleaned)"
                )
            }
        }

        // Post notification for cleaned orphans (toast display in ContentView)
        if cleanedCount > 0 {
            NotificationCenter.default.post(
                name: .zombieProcessesCleaned,
                object: nil,
                userInfo: ["count": cleanedCount]
            )
        }
    }

    @MainActor
    private func showAlertOnFirstLaunch() {
        let alert = NSAlert()
        alert.messageText = String(localized: "showAlertOnFirstLaunch.messageText")
        alert.informativeText = String(localized: "showAlertOnFirstLaunch.informativeText")
        alert.addButton(withTitle: String(localized: "showAlertOnFirstLaunch.button.moveToApplications"))
        alert.addButton(withTitle: String(localized: "showAlertOnFirstLaunch.button.dontMove"))

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let appURL = Bundle.main.bundleURL

            do {
                _ = try FileManager.default.replaceItemAt(AppDelegate.expectedUrl, withItemAt: appURL)
                NSWorkspace.shared.open(AppDelegate.expectedUrl)
            } catch {
                logger.error("Failed to move the app: \(error.localizedDescription)")
            }
        }
    }
}

extension Notification.Name {
    /// Posted when orphaned Wine processes are cleaned up at launch.
    /// Contains userInfo key "count" (Int) with the number of processes killed.
    static let zombieProcessesCleaned = Notification.Name("zombieProcessesCleaned")
}
