//
//  DependencyInstallSheet+Stages.swift
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

// MARK: - Info Stage

extension DependencyInstallSheet {
    /// Was a heading, two loose `Text`s and two `GroupBox`es doing two unrelated
    /// jobs. The facts are name and value pairs; the warning is a notice.
    @ViewBuilder
    var infoStage: some View {
        NCRow(title: definition.displayName, caption: definition.description) {
            EmptyView()
        }
        NCValueRow(
            name: "dependency.install.willInstall",
            value: definition.winetricksVerbs.joined(separator: ", ")
        )
        NCValueRow(
            name: "dependency.install.estimatedTime",
            value: String(localized: "dependency.install.minutes \(definition.estimatedInstallMinutes)"),
            isMachine: false
        )

        // Not reversible, so a real notice rather than a grey line in a box.
        NCNotice(
            status: .missing,
            message: String(localized: "dependency.install.warning")
        )
    }
}

// MARK: - Preflight Stage

extension DependencyInstallSheet {
    /// A checklist stage, drawn as one. The diagnostic behind a failure is the
    /// notice's message, where the orange `GroupBox` showed generic prose.
    @ViewBuilder
    var preflightStage: some View {
        if let result = preflightResult {
            NCChecklistRow(
                text: "dependency.install.prefixHealth",
                isDone: result.prefixValid
            )
            if !result.prefixValid {
                NCNotice(
                    status: .missing,
                    message: result.prefixMessage,
                    title: "dependency.install.prefixFailed"
                )
            }
        } else {
            NCNotice(
                status: .running,
                message: String(localized: "dependency.install.checkingPrefix")
            )
        }

        verbPlanSection
    }

    /// Each verb is machine text, so monospaced; the green `plus.circle.fill`
    /// becomes the shared badge, in `.available` — nothing here is installed.
    private var verbPlanSection: some View {
        NCSubsection(title: "dependency.install.verbPlan") {
            ForEach(definition.winetricksVerbs, id: \.self) { verb in
                NCRow(title: verb, isMachineTitle: true) {
                    NCStatusBadge(status: .available, label: "dependency.install.willAdd")
                }
            }
        }
    }
}

// MARK: - Running Stage

extension DependencyInstallSheet {
    /// The log was collapsed behind a `DisclosureGroup` while the thing it
    /// describes was happening. It is open, and live.
    @ViewBuilder
    var runningStage: some View {
        NCNotice(
            status: .running,
            message: String(localized: "dependency.install.runningFor \(definition.displayName)")
        )
        // Fills the body rather than taking a fixed height inside a scrolling
        // one. At a fixed height the transcript plus the notice above it
        // overflowed the sheet, so the sheet grew its own scrollbar alongside
        // the log's — two bars, and the outer one moved the whole screen.
        NCLogPanel(lines: logLines, isLive: true)
            .frame(maxHeight: .infinity)
    }
}

// MARK: - Verify Stage

extension DependencyInstallSheet {
    @ViewBuilder
    var verifyStage: some View {
        if let result = installResult {
            installResultNotice(result)
        }
        if let status = verifyStatus {
            verifyStatusNotice(status)
            // Where to look when the answer is not on screen.
            if let transcriptPath {
                NCRow(title: String(localized: "dependency.install.transcript"), machine: transcriptPath) {
                    EmptyView()
                }
            }
        } else {
            NCNotice(
                status: .running,
                message: String(localized: "dependency.install.rechecking")
            )
        }
    }

    /// A non-zero exit code is `.missing` rather than `.failed`: winetricks
    /// finished, which is a different thing from the run never completing.
    @ViewBuilder
    private func installResultNotice(_ result: InstallResult) -> some View {
        switch result {
        case .success:
            NCNotice(status: .ready, message: String(localized: "dependency.install.success"))
        case let .failure(exitCode):
            NCNotice(
                status: .missing,
                message: String(localized: "dependency.install.exitCode \(Int(exitCode))")
            )
        case let .error(message):
            NCNotice(status: .failed, message: String(localized: "dependency.install.error \(message)"))
        }
    }

    @ViewBuilder
    private func verifyStatusNotice(_ status: DependencyInstallStatus) -> some View {
        switch status {
        case .installed:
            NCNotice(status: .ready, message: String(localized: "dependency.install.verified"))
        case .partiallyInstalled:
            NCNotice(status: .missing, message: String(localized: "dependency.install.partialWarning"))
        case .notInstalled:
            NCNotice(status: .failed, message: String(localized: "dependency.install.notDetected"))
        case .unknown:
            NCNotice(status: .unknown, message: String(localized: "dependency.install.unverified"))
        }
    }
}
