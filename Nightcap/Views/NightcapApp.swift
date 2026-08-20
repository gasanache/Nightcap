// swiftlint:disable file_length
//
//  NightcapApp.swift
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

import NightcapKit
import os.log
import SwiftUI

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.gasanache.Nightcap",
    category: "NightcapApp"
)

@main
// swiftlint:disable:next type_body_length
struct NightcapApp: App {
    /// True when launched by the UI test harness (the `-NightcapUITestMode` launch
    /// argument set in `NightcapUITests`). UI tests run without a Wine runtime
    /// installed, which would otherwise auto-present the first-launch setup sheet
    /// over the main window and race every toolbar interaction; this lets that
    /// auto-presentation (and the update check) be skipped in tests.
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-NightcapUITestMode")

    /// Scene id for the main window, used to reopen it from the menu-bar extra.
    static let mainWindowID = "main"

    /// Scene id for the About window, opened from the App menu.
    static let aboutWindowID = "about"

    /// Opt-in: show a menu-bar extra and keep Nightcap running after the main
    /// window closes (see `AppDelegate.applicationShouldTerminateAfterLastWindowClosed`).
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = false
    @State var showSetup: Bool = false
    @State private var showMigrate: Bool = false
    @State private var showDiagnosticsSheet: Bool = false
    @State private var showTroubleshootingPicker: Bool = false
    @State private var showTroubleshootingWizard: Bool = false
    @State private var troubleshootingBottle: Bottle?
    @State private var troubleshootingProgram: Program?
    @State private var troubleshootingEntryContext: EntryContext?
    @State private var crashDiagnosisBanner: CrashDiagnosisBannerState?
    @State private var crashBannerDismissTask: Task<Void, Never>?
    /// One toast centre for the whole app. Thirteen views used to own or thread
    /// their own, and several of those overlays nested inside one another on
    /// the same window edge, so three messages could stack.
    @State private var toastCentre = NCToastCenter()
    @State private var audioMonitor = AudioDeviceMonitor()
    @State private var audioAlertTracker = AudioAlertTracker()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openURL) var openURL
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: Self.mainWindowID) {
            ContentView(showSetup: $showSetup)
                .frame(minWidth: ViewWidth.large, minHeight: ViewHeight.window)
                .environmentObject(BottleVM.shared)
                // Order matters and the compiler cannot catch it: `.environment`
                // writes into the subtree *below* it, so a modifier applied
                // afterwards is an ancestor of that write and reads an
                // environment with no centre in it. `NCToastLayer` reads the
                // centre non-optionally, so the wrong order is a hard trap on
                // the first frame, not a missing toast.
                .ncToastLayer()
                .environment(toastCentre)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                    Task.detached {
                        await NightcapApp.deleteOldLogs()
                    }
                    startAudioDeviceListening()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: .crashDiagnosisAvailable)
                ) { notification in
                    handleCrashDiagnosisNotification(notification)
                }
                .sheet(isPresented: $showDiagnosticsSheet) {
                    DiagnosticsPickerSheet()
                        .environmentObject(BottleVM.shared)
                }
                .sheet(isPresented: $showTroubleshootingPicker) {
                    TroubleshootingTargetPicker(
                        bottles: BottleVM.shared.bottles
                    ) { bottle, program in
                        troubleshootingBottle = bottle
                        troubleshootingProgram = program
                        troubleshootingEntryContext = .helpMenu(
                            bottleURL: bottle.url,
                            programURL: program?.url
                        )
                        showTroubleshootingWizard = true
                    }
                }
                .sheet(isPresented: $showTroubleshootingWizard) {
                    if let bottle = troubleshootingBottle,
                       let context = troubleshootingEntryContext {
                        TroubleshootingWizardView(
                            bottle: bottle,
                            program: troubleshootingProgram,
                            entryContext: context
                        )
                    }
                }
                .sheet(isPresented: $showMigrate) {
                    MigrateBottlesSheet()
                        .environmentObject(BottleVM.shared)
                }
                .overlay(alignment: .top) {
                    if let banner = crashDiagnosisBanner {
                        crashDiagnosisBannerView(banner)
                    }
                }
        }
        // Don't ask me how this works, it just does
        .handlesExternalEvents(matching: ["{same path of URL?}"])
        .commands {
            // Replacing `.appInfo` costs the system's own translation of
            // "About Nightcap", so `menu.about` is one of the few keys carried
            // in every language the app ships.
            CommandGroup(replacing: .appInfo) {
                Button("menu.about") {
                    openWindow(id: Self.aboutWindowID)
                }
            }
            CommandGroup(before: .systemServices) {
                Divider()
                Button("open.setup") {
                    showSetup = true
                }
                Button("install.cli") {
                    Task {
                        await NightcapCmd.install()
                    }
                }
            }
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("open.bottle") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.canCreateDirectories = false
                    panel.begin { result in
                        if result == .OK {
                            if let url = panel.urls.first {
                                // Task inherits main actor context from SwiftUI commands builder
                                Task {
                                    BottleVM.shared.bottlesList.paths.append(url)
                                    BottleVM.shared.loadBottles()
                                }
                            }
                        }
                    }
                }
                .keyboardShortcut("I", modifiers: [.command])
                Button("menu.migrateFromWhisky") {
                    showMigrate = true
                }
            }
            CommandGroup(after: .importExport) {
                Button("open.logs") {
                    NightcapApp.openLogsFolder()
                }
                .keyboardShortcut("L", modifiers: [.command])
                Button("kill.bottles") {
                    NightcapApp.killBottles()
                }
                .keyboardShortcut("K", modifiers: [.command, .shift])
                Button("wine.clearShaderCaches") {
                    NightcapApp.killBottles() // Better not make things more complicated for ourselves
                    NightcapApp.wipeShaderCaches()
                }
            }
            CommandGroup(replacing: .help) {
                Button("help.github") {
                    if let url = URL(string: "https://github.com/gasanache/Nightcap") {
                        openURL(url)
                    }
                }
                Button("help.issues") {
                    if let url = URL(string: "https://github.com/gasanache/Nightcap/issues") {
                        openURL(url)
                    }
                }
                Divider()
                Button("menu.runDiagnostics") {
                    showDiagnosticsSheet = true
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])
                Button(String(localized: "troubleshooting.entry.helpMenu")) {
                    showTroubleshootingPicker = true
                }
                .keyboardShortcut("T", modifiers: [.command, .shift])
            }
        }
        Settings {
            SettingsView()
        }
        // A single window rather than a `WindowGroup`: asking for About twice
        // should raise the one that is already open, not stack a second copy.
        // It sizes itself to its content, so the layout decides the window
        // rather than a guessed frame.
        Window("menu.about", id: Self.aboutWindowID) {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
        .commandsRemoved()
        MenuBarExtra("Nightcap", systemImage: "wineglass", isInserted: $showMenuBarExtra) {
            NightcapMenuBarView()
                .environmentObject(BottleVM.shared)
        }
    }

    // MARK: - Crash Diagnosis Notification

    private func handleCrashDiagnosisNotification(_ notification: Notification) {
        guard let diagnosis = notification.userInfo?["diagnosis"] as? CrashDiagnosis,
              let programPath = notification.userInfo?["programPath"] as? String,
              let logFileURL = notification.userInfo?["logFileURL"] as? URL
        else { return }

        let programName = URL(fileURLWithPath: programPath).deletingPathExtension().lastPathComponent
        let banner = CrashDiagnosisBannerState(
            diagnosis: diagnosis,
            programName: programName,
            programPath: programPath,
            logFileURL: logFileURL
        )
        crashDiagnosisBanner = banner

        // Auto-dismiss after 8 seconds. Held and cancelled on replacement:
        // fire-and-forget, a second crash inside the window had its banner
        // dismissed early by the first banner's timer.
        crashBannerDismissTask?.cancel()
        crashBannerDismissTask = Task {
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, crashDiagnosisBanner == banner else { return }
            withAnimation {
                crashDiagnosisBanner = nil
            }
        }
    }

    private func crashDiagnosisBannerView(_ banner: CrashDiagnosisBannerState) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("crash.banner \(banner.programName)")
                .fontWeight(.medium)
            Spacer()
            Button(String(localized: "troubleshooting.entry.troubleshoot")) {
                openTroubleshootingFromCrash(banner)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Button {
                withAnimation {
                    crashDiagnosisBanner = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .shadow(radius: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Troubleshooting from Crash Banner

    private func openTroubleshootingFromCrash(_ banner: CrashDiagnosisBannerState) {
        withAnimation {
            crashDiagnosisBanner = nil
        }

        // Find the bottle and program for this crash, by the crashed
        // executable's real path. The old code derived a path from the log
        // folder (never inside a bottle) and matched the first program of any
        // bottle via a wildcard predicate — so it never targeted correctly.
        let programPath = banner.programPath
        for bottle in BottleVM.shared.bottles
            where programPath.contains(bottle.url.path(percentEncoded: false)) {
            if let program = bottle.programs.first(where: {
                $0.url.path(percentEncoded: false) == programPath
            }) {
                let evidence: [String: String] = [
                    "crashCategory": banner.diagnosis.primaryCategory?.rawValue ?? "unknown",
                    "logFileURL": banner.logFileURL.absoluteString
                ]
                troubleshootingBottle = bottle
                troubleshootingProgram = program
                troubleshootingEntryContext = .launchFailure(
                    programURL: program.url,
                    bottleURL: bottle.url,
                    evidence: evidence
                )
                showTroubleshootingWizard = true
                return
            }
        }

        // Fallback: open picker if we could not match the program
        showTroubleshootingPicker = true
    }

    // MARK: - Audio Device Alerts

    private func startAudioDeviceListening() {
        audioMonitor.startListening { event in
            Task { @MainActor in
                guard audioAlertTracker.shouldAlert(deviceName: event.deviceName) else { return }

                switch event.eventType {
                case .defaultOutputChanged, .disconnected:
                    let message = String(
                        localized: "audio.alert.disconnected"
                    ) + ": \(event.deviceName)"
                    toastCentre.show(
                        message,
                        status: .available
                    )
                case .reconnected:
                    let message = String(
                        localized: "audio.alert.reconnected"
                    ) + ": \(event.deviceName)"
                    toastCentre.show(
                        message,
                        status: .ready
                    )
                case .sampleRateChanged:
                    // Check for low sample rate (HFP/Bluetooth issue)
                    if let device = audioMonitor.defaultOutputDevice(),
                       device.sampleRate < 22_050, device.sampleRate > 0 {
                        let message = String(localized: "audio.alert.lowSampleRate")
                            + ": \(event.deviceName)"
                        toastCentre.show(
                            message,
                            status: .available
                        )
                    }
                }
            }
        }
    }
}

// MARK: - NightcapApp Utility Methods

extension NightcapApp {
    @MainActor
    static func killBottles() {
        for bottle in BottleVM.shared.bottles {
            // killBottle is fire-and-forget; errors are logged internally
            Wine.killBottle(bottle: bottle)
        }
    }

    static func openLogsFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: Wine.logsFolder.path)
    }

    static func deleteOldLogs() {
        let pastDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: Wine.logsFolder,
            includingPropertiesForKeys: [.creationDateKey]
        )
        else {
            return
        }

        let logs = urls.filter { url in
            url.pathExtension == "log"
        }

        let oldLogs = logs.filter { url in
            do {
                let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])

                return resourceValues.creationDate ?? Date() < pastDate
            } catch {
                return false
            }
        }

        for log in oldLogs {
            do {
                try FileManager.default.removeItem(at: log)
            } catch {
                logger.warning("Failed to delete log: \(error.localizedDescription)")
            }
        }
    }

    static func wipeShaderCaches() {
        let getconf = Process()
        getconf.executableURL = URL(fileURLWithPath: "/usr/bin/getconf")
        getconf.arguments = ["DARWIN_USER_CACHE_DIR"]
        let pipe = Pipe()
        getconf.standardOutput = pipe
        do {
            try getconf.run()
        } catch {
            logger.error("Failed to run getconf: \(error.localizedDescription)")
            return
        }
        getconf.waitUntilExit()

        let getconfOutput: Data
        do {
            getconfOutput = try pipe.fileHandleForReading.readToEnd() ?? Data()
        } catch {
            logger.error("Failed to read getconf output: \(error.localizedDescription)")
            return
        }

        guard let getconfOutputString = String(data: getconfOutput, encoding: .utf8) else {
            logger.error("Failed to decode getconf output as UTF-8")
            return
        }
        let d3dmPath = URL(fileURLWithPath: getconfOutputString.trimmingCharacters(in: .whitespacesAndNewlines))
            .appending(path: "d3dm").path
        do {
            try FileManager.default.removeItem(atPath: d3dmPath)
            logger.info("Successfully cleared shader caches")
        } catch {
            logger.warning("Failed to remove shader cache at \(d3dmPath): \(error.localizedDescription)")
        }
    }
}
