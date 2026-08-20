//
//  DependencyInstallSheet.swift
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
import SwiftUI

/// Posted once an install has finished and been verified, carrying the bottle
/// URL. Anything showing dependency state reloads on it: the list that opened
/// this sheet stays mounted behind it, so its `onAppear` never fires again and
/// it would otherwise keep showing what it read before the install.
extension Notification.Name {
    static let dependenciesChanged = Notification.Name("dependenciesChanged")
}

/// Guided dependency install: what you are getting, whether the prefix can take
/// it, the install itself, and what actually landed. Installation never happens
/// silently — the user must explicitly click Install.
///
/// Each of the four stages wrote its own `.title2` semibold heading inside a
/// sheet that had no title of its own, so the sheet was headed four different
/// ways and nothing said which of the four you were on. The stage is now the
/// title, with a step count and a progress bar above it.
struct DependencyInstallSheet: View {
    let definition: DependencyDefinition
    @ObservedObject var bottle: Bottle
    @Environment(\.dismiss) private var dismiss

    @State private var stage: InstallStage = .info
    // Not `private`: the four stage views live in
    // DependencyInstallSheet+Stages.swift, and `private` does not cross a
    // file boundary.
    @State var logLines: [String] = []
    @State var installResult: InstallResult?
    @State var preflightResult: PreflightResult?
    @State var verifyStatus: DependencyInstallStatus?
    @State var transcriptPath: String?

    var body: some View {
        // Sized to fit the window, not the content's wishes: at 620pt this
        // overhung a ~530pt host and was clipped, footer buttons first.
        NCSheet(
            title: stage.title,
            width: ViewWidth.medium,
            height: ViewHeight.medium,
            eyebrow: stageEyebrow,
            progress: stageProgress,
            scrolls: stage != .running
        ) {
            stageContent
        } footer: {
            footerButtons
        }
    }

    private var stageEyebrow: LocalizedStringKey {
        "dependency.install.step \(stage.rawValue + 1) \(InstallStage.allCases.count)"
    }

    private var stageProgress: Double {
        Double(stage.rawValue + 1) / Double(InstallStage.allCases.count)
    }

    private var stageContent: some View {
        VStack(alignment: .leading, spacing: Theme.Space.card) {
            switch stage {
            case .info:
                infoStage
            case .preflight:
                preflightStage
            case .running:
                runningStage
            case .verify:
                verifyStage
            }
        }
    }
}

// MARK: - Install Stage

extension DependencyInstallSheet {
    enum InstallStage: Int, CaseIterable {
        case info
        case preflight
        case running
        case verify

        /// Four headings drawn inside the body; they are the one title now.
        var title: LocalizedStringKey {
            switch self {
            case .info: "dependency.install.what"
            case .preflight: "dependency.install.preflight"
            case .running: "dependency.install.running"
            case .verify: "dependency.install.verify"
            }
        }
    }

    enum InstallResult {
        case success
        case failure(exitCode: Int32)
        case error(String)
    }

    struct PreflightResult {
        let prefixValid: Bool
        let prefixMessage: String
    }
}

// MARK: - Footer

extension DependencyInstallSheet {
    @ViewBuilder
    private var footerButtons: some View {
        // Cancel during the running stage dismisses the sheet while winetricks
        // keeps streaming in the background. Left exactly as it was found.
        if stage != .verify {
            Button("create.cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }

        NCFooterSpacer()

        switch stage {
        case .info:
            Button("dependency.install.continue") {
                stage = .preflight
                runPreflightChecks()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        case .preflight:
            Button("dependency.install") {
                startInstallation()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(preflightResult == nil)
        case .running:
            EmptyView()
        case .verify:
            Button("dependency.install.done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Actions

extension DependencyInstallSheet {
    private func runPreflightChecks() {
        Task {
            let result = await MainActor.run {
                WinePrefixValidation.validatePrefix(for: bottle)
            }
            let preflight = PreflightResult(
                prefixValid: result.isValid,
                prefixMessage: result.isValid
                    ? "Prefix is healthy and ready for installation"
                    : result.diagnostics?.events.last ?? "Prefix validation failed"
            )
            await MainActor.run {
                preflightResult = preflight
            }
        }
    }

    private func startInstallation() {
        stage = .running
        logLines = []

        Task {
            let verbStream = Winetricks.installVerbs(definition.winetricksVerbs, for: bottle)
            // Success used to be decided by the LAST verb's exit code alone, so
            // a definition whose first verb failed and second passed reported
            // success. Every verb's outcome counts now.
            var firstFailure: Int32?
            var hadError = false
            var didTimeOut = false

            for await (verb, progress) in verbStream {
                await MainActor.run {
                    switch progress {
                    case .preparing:
                        logLines.append("[\(verb)] Preparing\u{2026}")
                    case let .output(line):
                        logLines.append("[\(verb)] \(line)")
                    case let .completed(exitCode):
                        logLines.append("[\(verb)] Completed (exit code: \(exitCode))")
                        if exitCode != 0, firstFailure == nil {
                            firstFailure = exitCode
                        }
                    case let .failed(message):
                        logLines.append("[\(verb)] FAILED: \(message)")
                        hadError = true
                    case let .timedOut(seconds):
                        logLines.append("[\(verb)] TIMED OUT after \(seconds / 60) minutes")
                        didTimeOut = true
                    }
                }
            }

            let result: InstallResult = if didTimeOut {
                .error(String(localized: "dependency.install.timedOut"))
            } else if hadError {
                .error("One or more verbs failed")
            } else if let firstFailure {
                .failure(exitCode: firstFailure)
            } else {
                .success
            }

            await MainActor.run {
                installResult = result
                stage = .verify
            }

            await writeTranscript()
            await runVerification()
            await saveInstallAttempt(result)
        }
    }

    /// Puts the streamed output on disk before the sheet can be closed.
    ///
    /// The transcript lived only in view state, so the one place the reason for
    /// a failure existed was destroyed by dismissing the sheet that reported
    /// it. Written for successes too — a verb that "worked" but installed
    /// nothing is exactly the case worth reading afterwards.
    private func writeTranscript() async {
        let (bottleURL, lines) = await MainActor.run { (bottle.url, logLines) }
        guard !lines.isEmpty else { return }
        let folder = bottleURL.appending(path: "InstallLogs")
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let file = folder.appending(path: "\(definition.id)-\(stamp).log")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
            await MainActor.run { transcriptPath = file.path(percentEncoded: false) }
        } catch {
            // Losing the transcript must not also lose the install result.
            await MainActor.run { transcriptPath = nil }
        }
    }

    private func runVerification() async {
        let statuses = await DependencyManager.checkDependencies(
            for: bottle,
            definitions: [definition]
        )
        await MainActor.run {
            verifyStatus = statuses.first?.status ?? .unknown
            NotificationCenter.default.post(
                name: .dependenciesChanged,
                object: bottle.url
            )
        }
    }

    private func saveInstallAttempt(_ result: InstallResult) async {
        let bottleURL = await MainActor.run { bottle.url }
        var history = BottleDependencyHistory.load(from: bottleURL) ?? BottleDependencyHistory()

        let success: Bool
        let exitCode: Int32?
        switch result {
        case .success:
            success = true
            exitCode = 0
        case let .failure(code):
            success = false
            exitCode = code
        case .error:
            success = false
            exitCode = nil
        }

        let attempt = DependencyInstallAttempt(
            definitionId: definition.id,
            verbsAttempted: definition.winetricksVerbs,
            timestamp: Date(),
            success: success,
            exitCode: exitCode
        )
        history.append(attempt)
        try? history.save(to: bottleURL)
    }
}
