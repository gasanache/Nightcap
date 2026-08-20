//
//  Wine+ProcessManagement.swift
//  NightcapKit
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
import os.log

private let processLogger = Logger(
    subsystem: Bundle.nightcapBundleIdentifier,
    category: "Wine.ProcessManagement"
)

/// Posted whenever the process registry's contents change, so views showing
/// counts can refresh instead of reading once and going stale.
public extension Notification.Name {
    static let processRegistryChanged = Notification.Name("processRegistryChanged")
}

extension ProcessRegistry {
    /// Callers hold the lock on arbitrary threads; observers are SwiftUI
    /// views, so the post hops to main and lands outside any lock.
    func notifyChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .processRegistryChanged, object: nil)
        }
    }
}

// MARK: - Wine Process Management Helpers

public extension Wine {
    /// Probes whether a wineserver is currently running for the given bottle.
    ///
    /// Uses `wineserver -k0` which sends signal 0 (a no-op) to the wineserver.
    /// Exit code 0 means the wineserver is alive; any other code (or error)
    /// means it is not running. This does **not** spawn a new wineserver.
    ///
    /// - Parameter bottle: The bottle whose wineserver to probe.
    /// - Returns: `true` if the wineserver is active, `false` otherwise.
    @MainActor
    static func isWineserverRunning(for bottle: Bottle) async -> Bool {
        let running = await isWineserverRunning(forPrefixAt: bottle.url)
        processLogger.debug(
            "Wineserver probe for '\(bottle.settings.name)': \(running ? "active" : "idle")"
        )
        return running
    }

    /// The same probe by prefix URL, for callers that hold no ``Bottle`` —
    /// the troubleshooting checks run off the main actor with only a URL.
    static func isWineserverRunning(forPrefixAt url: URL) async -> Bool {
        // Deliberately does NOT go through runWineserverProcess: a -k0 probe
        // only needs WINEPREFIX, while the full path builds the entire launch
        // environment and creates + retention-scans a log file per call — the
        // sidebar repeats this probe every 60 seconds for every visible bottle.
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = NightcapWineInstaller.binFolder.appending(path: "wineserver")
            process.arguments = ["-k0"]
            process.environment = ["WINEPREFIX": url.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { probe in
                continuation.resume(returning: probe.terminationStatus == 0)
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: false)
            }
        }
    }

    /// Parses the CSV output of `tasklist.exe` into an array of ``WineProcess`` values.
    ///
    /// The expected format is quoted CSV with a header line:
    /// ```
    /// "Image Name","PID","Session Name","Session#","Mem Usage"
    /// "game.exe","42","Console","0","24 K"
    /// ```
    ///
    /// Lines that cannot be parsed (wrong field count, non-numeric PID) are silently skipped.
    /// All returned processes have ``ProcessSource/untracked`` source; the caller should
    /// update the source after merging with ``ProcessRegistry`` data.
    ///
    /// - Parameter output: The raw string output from `tasklist.exe`.
    /// - Returns: An array of parsed ``WineProcess`` instances.
    static func parseTasklistOutput(_ output: String) -> [WineProcess] {
        let lines = output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
        var processes: [WineProcess] = []
        processes.reserveCapacity(lines.count)

        for line in lines {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
                .map { field in
                    var trimmed = field.trimmingCharacters(in: .whitespaces)
                    // Strip surrounding quotes
                    if trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") {
                        trimmed = String(trimmed.dropFirst().dropLast())
                    }
                    return trimmed
                }

            // Require at least 5 fields: Image Name, PID, Session Name, Session#, Mem Usage
            guard fields.count >= 5 else { continue }

            // Skip the header line
            if fields[1] == "PID" { continue }

            // Parse the PID
            guard let pid = Int32(fields[1]) else { continue }

            let imageName = fields[0]
            let memoryUsage = fields[4]

            processes.append(WineProcess(
                imageName: imageName,
                winePID: pid,
                memoryUsage: memoryUsage,
                kind: ProcessKind.classify(imageName)
            ))
        }

        return processes
    }

    /// Sends a graceful kill request for a single Wine process via `taskkill.exe`.
    ///
    /// This asks the process to terminate cleanly. If the process has already
    /// exited, the error is silently ignored.
    ///
    /// - Parameters:
    ///   - winePID: The Wine/Windows PID to terminate.
    ///   - bottle: The bottle containing the process.
    @MainActor
    static func gracefulKillProcess(winePID: Int32, bottle: Bottle) async {
        do {
            try await Wine.runWine(
                ["taskkill.exe", "/PID", String(winePID)],
                bottle: bottle
            )
            processLogger.info("Sent graceful kill to Wine PID \(winePID)")
        } catch {
            processLogger.debug(
                "Graceful kill for Wine PID \(winePID) failed (process may have exited): \(error.localizedDescription)"
            )
        }
    }

    /// Sends a forced kill request for a single Wine process via `taskkill.exe /F`.
    ///
    /// This forcefully terminates the process without giving it a chance to
    /// clean up. If the process has already exited, the error is silently ignored.
    ///
    /// - Parameters:
    ///   - winePID: The Wine/Windows PID to terminate.
    ///   - bottle: The bottle containing the process.
    @MainActor
    static func forceKillProcess(winePID: Int32, bottle: Bottle) async {
        do {
            try await Wine.runWine(
                ["taskkill.exe", "/PID", String(winePID), "/F"],
                bottle: bottle
            )
            processLogger.info("Sent force kill to Wine PID \(winePID)")
        } catch {
            processLogger.debug(
                "Force kill for Wine PID \(winePID) failed (process may have exited): \(error.localizedDescription)"
            )
        }
    }
}
