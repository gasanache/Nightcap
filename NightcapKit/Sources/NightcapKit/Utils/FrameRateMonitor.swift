//
//  FrameRateMonitor.swift
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
import os.log

/// Live frame rate for the running program, read from the launch log.
///
/// WineD3D has no on-screen overlay — the DXVK HUD needs DXVK and Apple's
/// Metal HUD only attaches to native Metal apps — so on that backend Wine's
/// `fps` debug channel is the only frame-rate source there is, and it reports
/// by writing `approx 42.5fps` into the log. This follows the newest log and
/// turns those lines into a reading the app can show.
///
/// Enabling the channel is the Diagnostics On preset's job; without it the log
/// carries no readings and this stays empty.
@MainActor
public final class FrameRateMonitor: ObservableObject {
    /// The most recent reading, or nil when nothing has been reported yet.
    @Published public private(set) var current: Double?
    /// Mean of every reading seen this session.
    @Published public private(set) var average: Double?
    /// Lowest reading seen this session, which is what stutter looks like.
    @Published public private(set) var minimum: Double?
    /// Number of readings collected.
    @Published public private(set) var sampleCount: Int = 0

    private var pollTask: Task<Void, Never>?
    private var logURL: URL?
    private var offset: UInt64 = 0
    private var total: Double = 0
    private let logsFolder: URL
    private static let pattern = /approx ([0-9.]+)fps/

    public init(logsFolder: URL = Wine.logsFolder) {
        self.logsFolder = logsFolder
    }

    deinit {
        // Task is Sendable, so cancelling from a nonisolated deinit is safe.
        pollTask?.cancel()
    }

    /// Begins following the newest log.
    public func start(pollInterval: Duration = .seconds(1)) {
        stop()
        reset()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: pollInterval)
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Clears readings, so switching configurations doesn't average across both.
    public func reset() {
        current = nil
        average = nil
        minimum = nil
        sampleCount = 0
        total = 0
        offset = 0
        logURL = nil
    }

    private func poll() {
        guard let url = newestLog() else { return }

        // A new launch means a new log: start from its beginning.
        if url != logURL {
            logURL = url
            offset = 0
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        // Only read what has been appended since the last poll — these logs
        // reach tens of megabytes with the fps channel on.
        try? handle.seek(toOffset: offset)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return }
        offset += UInt64(data.count)

        guard let text = String(data: data, encoding: .utf8) else { return }
        for match in text.matches(of: Self.pattern) {
            guard let value = Double(match.1) else { continue }
            record(value)
        }
    }

    private func record(_ value: Double) {
        current = value
        sampleCount += 1
        total += value
        average = total / Double(sampleCount)
        minimum = min(minimum ?? value, value)
    }

    private func newestLog() -> URL? {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logsFolder,
            includingPropertiesForKeys: keys
        )
        else {
            return nil
        }
        return files
            .filter { $0.pathExtension == "log" }
            .max { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
                return lhsDate < rhsDate
            }
    }
}
