//
//  FixPreviewView.swift
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

/// Diff-style fix preview with explicit Apply button and confirmation for high-impact changes.
///
/// Shows current and proposed values side by side in a monospace diff layout.
/// Uses ``FixApplicator/preview(fixId:params:bottle:program:)`` to fetch
/// the current/new values and ``FixApplicator/apply(fixId:params:bottle:program:)``
/// to execute the fix. Per locked decision, the Apply button is explicit and gated.
struct FixPreviewView: View {
    let node: FlowStepNode
    @ObservedObject var engine: TroubleshootingFlowEngine
    let bottle: Bottle
    let program: Program?

    @State private var fixPreview: FixPreview?
    @State private var showConfirmation: Bool = false
    @State private var isApplying: Bool = false
    @State private var applyError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            if let fixPreview {
                diffPreviewSection(fixPreview)
                reversibilityIndicator(fixPreview)
            } else {
                fallbackDescription
            }
            actionButtons
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .onAppear(perform: loadPreview)
        .alert("Confirm Fix", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Apply") { applyFix() }
        } message: {
            Text(confirmationMessage)
        }
    }
}

// MARK: - Header

extension FixPreviewView {
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                if let title = node.title {
                    Text(title)
                        .font(.headline)
                }
            }
            if let description = node.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fallbackDescription: some View {
        Group {
            if let description = node.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Diff Preview

extension FixPreviewView {
    private func diffPreviewSection(_ preview: FixPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preview.settingName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                // Current value (red, being removed)
                HStack(spacing: 6) {
                    Text("\u{2212}")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.red)
                    Text(preview.currentValue)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // New value (green, being applied)
                HStack(spacing: 6) {
                    Text("+")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.green)
                    Text(preview.newValue)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text("Scope: \(preview.scope)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Reversibility Indicator

extension FixPreviewView {
    private func reversibilityIndicator(_ preview: FixPreview) -> some View {
        HStack(spacing: 6) {
            if preview.isReversible {
                Image(systemName: "arrow.uturn.backward.circle")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text("This change can be undone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("This action cannot be undone")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Action Buttons

extension FixPreviewView {
    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Button("Skip for now") {
                engine.skipStep()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                if node.requiresConfirmation == true {
                    showConfirmation = true
                } else {
                    applyFix()
                }
            } label: {
                if isApplying {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Apply Fix")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isApplying)
        }
        if let applyError {
            Label(applyError, systemImage: "xmark.circle")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var confirmationMessage: String {
        if let preview = fixPreview {
            "This will change \(preview.settingName) from "
                + "\"\(preview.currentValue)\" to \"\(preview.newValue)\"."
        } else {
            "Are you sure you want to apply this fix?"
        }
    }
}

// MARK: - Actions

extension FixPreviewView {
    private func loadPreview() {
        guard let fixId = node.fixId else { return }
        fixPreview = FixApplicator.preview(
            fixId: fixId,
            params: node.params ?? [:],
            bottle: bottle,
            program: program
        )
    }

    private func applyFix() {
        guard let fixId = node.fixId else { return }
        isApplying = true
        applyError = nil

        Task {
            // The restart fix used to fire-and-forget the kill and report
            // "restarted" while the server was still up; wait for it first so
            // the verify step sees the truth.
            if fixId == "restart-wineserver" {
                await Wine.killBottleAndWait(bottle: bottle)
            }

            let attempt = FixApplicator.apply(
                fixId: fixId,
                params: node.params ?? [:],
                bottle: bottle,
                program: program
            )

            // `.pending` means the applicator changed nothing itself. For the
            // install fixes that used to be the whole story — the comment said
            // "delegated to the Winetricks infrastructure" and no delegation
            // existed, so the history recorded installs that never ran.
            var outcome = attempt.result
            if outcome == .pending {
                outcome = await runPendingWork(fixId: fixId)
            }

            engine.applyFix(
                fixId: fixId,
                beforeValue: attempt.beforeValue,
                afterValue: attempt.afterValue
            )
            // The result used to be discarded here, so a failed apply was
            // recorded as applied and the flow moved on satisfied.
            if outcome == .failed {
                applyError = String(localized: "troubleshooting.fix.failed")
            } else {
                engine.confirmFixApplied(fixId: fixId)
            }
            isApplying = false
        }
    }

    /// Runs the async work behind a `.pending` attempt and reports how it went.
    private func runPendingWork(fixId: String) async -> FixResult {
        switch fixId {
        case "install-winetricks-verb", "install-dependency":
            let verbs = pendingVerbs(for: fixId)
            guard !verbs.isEmpty else { return .failed }
            var failed = false
            for await (_, progress) in Winetricks.installVerbs(verbs, for: bottle) {
                switch progress {
                case let .completed(exitCode) where exitCode != 0: failed = true
                case .failed, .timedOut: failed = true
                default: break
                }
            }
            return failed ? .failed : .applied
        default:
            // Settings-only pendings (e.g. the buffer preset) took effect when
            // the setting was written; nothing further to run.
            return .applied
        }
    }

    private func pendingVerbs(for fixId: String) -> [String] {
        let params = node.params ?? [:]
        if fixId == "install-winetricks-verb" {
            return params["verb"].map { [$0] } ?? []
        }
        let id = params["dependency"] ?? ""
        return DependencyDefinition.standardDependencies
            .first { $0.id == id }?.winetricksVerbs ?? []
    }
}
