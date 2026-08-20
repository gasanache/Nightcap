//
//  Winetricks+InstalledVerbs.swift
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

private let logger = Logger(subsystem: Bundle.nightcapBundleIdentifier, category: "Winetricks")

// MARK: - Installed Verb Discovery

// swiftlint:disable function_body_length

extension Winetricks {
    /// Runs `winetricks list-installed` as a headless process to discover installed verbs.
    ///
    /// - Parameter bottle: The bottle whose prefix to query.
    /// - Returns: A set of installed verb names, or `nil` if the process fails or times out.
    static func listInstalledVerbs(for bottle: Bottle) async -> Set<String>? {
        let bottleURL = await MainActor.run { bottle.url }
        logger.debug("Running winetricks list-installed for bottle at \(bottleURL.path)")

        guard let resourcesURL = Bundle.main.url(forResource: "cabextract", withExtension: nil)?
            .deletingLastPathComponent()
        else {
            logger.warning("Could not locate cabextract resource for winetricks")
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let winetricksPath = resourcesURL.appending(path: "winetricks").path(percentEncoded: false)
        process.arguments = ["bash", winetricksPath, "list-installed"]
        process.environment = [
            "WINEPREFIX": bottleURL.path(percentEncoded: false),
            "WINE": "wine64",
            "PATH": [
                NightcapWineInstaller.binFolder.path(percentEncoded: false),
                resourcesURL.path(percentEncoded: false),
                "/usr/bin",
                "/bin"
            ].joined(separator: ":"),
            "HOME": NSHomeDirectory()
        ]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logger.error("Failed to launch winetricks list-installed: \(error.localizedDescription)")
            return nil
        }

        // 30-second timeout
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(30))
            if process.isRunning {
                logger.warning("winetricks list-installed timed out after 30 seconds")
                process.terminate()
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        guard process.terminationStatus == 0 else {
            logger.warning(
                "winetricks list-installed exited with status \(process.terminationStatus)"
            )
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        let verbs = Self.verbNames(from: output)

        if verbs.isEmpty {
            return nil
        }

        logger.debug("winetricks list-installed found \(verbs.count) verbs")
        return verbs
    }

    /// The verb names in a block of winetricks output.
    ///
    /// Winetricks writes its banner to stdout alongside the list — the
    /// taskset/cpuset warning, the "Using winetricks <date> - sha256sum: …"
    /// line — and the previous parse took every non-empty line as a verb, so
    /// those banners were cached and counted as installed components. The log
    /// also records some entries with an argument ("remove_mono internal"),
    /// where only the first token is the verb.
    ///
    /// A verb is one lowercase token: letters, digits, `_`, `.`, `+` or `-`.
    /// Anything else is winetricks talking, not a verb.
    static func verbNames(from output: String) -> Set<String> {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_.+-")
        let names = output
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                guard let token = line
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: .whitespaces)
                    .first,
                    !token.isEmpty,
                    token.rangeOfCharacter(from: allowed.inverted) == nil,
                    token.first?.isLetter == true || token.first?.isNumber == true
                else { return nil }
                return token
            }
        return Set(names)
    }

    /// Parses the winetricks.log file as a fallback verb discovery method.
    ///
    /// Checks both the prefix root and drive_c locations for the log file.
    /// Each successfully installed verb appears on its own line in the log.
    ///
    /// - Parameter bottle: The bottle whose log to parse.
    /// - Returns: A set of verb names found in the log (best-effort).
    static func parseWinetricksLog(for bottle: Bottle) async -> Set<String> {
        let bottleURL = await MainActor.run { bottle.url }
        let prefixLogURL = bottleURL.appending(path: "winetricks.log")
        let driveCLogURL = bottleURL
            .appending(path: "drive_c")
            .appending(path: "winetricks.log")

        var contents: String?
        if let data = try? Data(contentsOf: prefixLogURL) {
            contents = String(data: data, encoding: .utf8)
        } else if let data = try? Data(contentsOf: driveCLogURL) {
            contents = String(data: data, encoding: .utf8)
        }

        guard let logContents = contents else {
            return []
        }

        var verbs = Set<String>()
        for line in logContents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("Executing load_") {
                let verb = String(trimmed.dropFirst("Executing load_".count))
                if !verb.isEmpty {
                    verbs.insert(verb)
                }
            } else if trimmed.hasPrefix("Installed ") {
                let verb = String(trimmed.dropFirst("Installed ".count))
                    .trimmingCharacters(in: .whitespaces)
                if !verb.isEmpty {
                    verbs.insert(verb)
                }
            } else if !trimmed.contains(" ") {
                verbs.insert(trimmed)
            }
        }

        return verbs
    }

    /// Loads installed verbs for a bottle, using the cache when possible.
    ///
    /// Flow:
    /// 1. Load cache from disk (instant)
    /// 2. Check staleness via winetricks.log file attributes
    /// 3. If cache is fresh, return cached data
    /// 4. Otherwise, try `list-installed` first, fall back to log parsing
    /// 5. Save updated cache and return
    ///
    /// - Parameter bottle: The bottle to check.
    /// - Returns: A tuple of the installed verb set and whether the data came from cache.
    static func loadInstalledVerbs(
        for bottle: Bottle
    ) async -> (verbs: Set<String>, fromCache: Bool) {
        let bottleURL = await MainActor.run { bottle.url }

        let cache = WinetricksVerbCache.load(from: bottleURL)
        let logInfo = WinetricksVerbCache.winetricksLogInfo(for: bottleURL)

        // Return cached data if still fresh
        if let cache, !cache.isStale(
            currentLogSize: logInfo.size,
            currentLogModDate: logInfo.modDate
        ) {
            // Sanitised on the way out as well as in: caches written before
            // `verbNames(from:)` existed hold winetricks' banner lines as
            // though they were verbs, and they stay valid until the prefix
            // changes. Filtering here heals them without a forced re-scan.
            return (Self.verbNames(from: cache.installedVerbs.joined(separator: "\n")), true)
        }

        // Cache is stale or missing; try list-installed first
        let verbs: Set<String> = if let discovered = await listInstalledVerbs(for: bottle) {
            discovered
        } else {
            await parseWinetricksLog(for: bottle)
        }

        var newCache = WinetricksVerbCache(installedVerbs: verbs, lastChecked: Date())
        newCache.logFileSize = logInfo.size
        newCache.logFileModDate = logInfo.modDate
        try? WinetricksVerbCache.save(newCache, to: bottleURL)

        return (verbs, false)
    }
}

// swiftlint:enable function_body_length
