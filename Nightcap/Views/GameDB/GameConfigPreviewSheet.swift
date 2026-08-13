//
//  GameConfigPreviewSheet.swift
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

/// A sheet that shows a before/after diff of what settings will change when
/// applying a game configuration variant, with winetricks preflight and apply action.
struct GameConfigPreviewSheet: View {
    let entry: GameDBEntry
    let variant: GameConfigVariant
    @ObservedObject var bottle: Bottle
    let programURL: URL?
    @Environment(\.dismiss) private var dismiss
    /// Read by the diff rows, which live in `GameConfigPreviewSheet+Changes.swift`.
    @State var changes: [ConfigChange] = []
    @State private var installedVerbs: Set<String> = []
    /// Whether the installed-verb scan has landed. Apply waits on it.
    @State private var didScanVerbs: Bool = false
    @State private var isApplying: Bool = false
    @State private var applyError: String?
    @State private var stalenessResult: StalenessResult?
    @State private var includeWinetricks: Bool = true
    /// The verbs this variant still needs, resolved when the preview loads.
    /// Holding it is not the same as installing it -- see ``installing``.
    @State private var missingDependency: DependencyDefinition?
    /// Non-nil only while the install sheet is up, which is what presents it.
    @State private var installing: DependencyDefinition?
    @AppStorage("gameConfigSkipPreview") private var skipPreview: Bool = false
    @Binding var toast: ToastData?

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    stalenessWarning
                    applyTargetSection
                    changesSection
                    winetricksSection
                    restartNote
                    errorBanner
                }
                .padding()
            }
            sheetFooter
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 400, idealHeight: 600)
        .task {
            await loadPreviewData()
        }
        .sheet(item: $installing, onDismiss: finishAfterInstall) { definition in
            DependencyInstallSheet(definition: definition, bottle: bottle)
                .frame(minWidth: 500, minHeight: 400)
        }
    }
}

// MARK: - Header

extension GameConfigPreviewSheet {
    private var sheetHeader: some View {
        VStack(spacing: 4) {
            Text("gameConfig.preview.title")
                .font(.headline)
            Text(entry.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

// MARK: - Staleness Warning

extension GameConfigPreviewSheet {
    @ViewBuilder
    private var stalenessWarning: some View {
        if let result = stalenessResult, result.isStale, let message = result.warningMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("gameConfig.preview.staleConfig")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Apply Target

extension GameConfigPreviewSheet {
    private var applyTargetSection: some View {
        HStack {
            Text("gameConfig.preview.applyTo")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(bottle.settings.name)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Winetricks Section

extension GameConfigPreviewSheet {
    @ViewBuilder
    private var winetricksSection: some View {
        if let verbs = variant.winetricksVerbs, !verbs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("gameConfig.preview.winetricksRequired")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(verbs, id: \.self) { verb in
                    verbRow(verb)
                }

                Toggle("gameConfig.preview.installComponents", isOn: $includeWinetricks)
                    .font(.caption)

                if !includeWinetricks {
                    Text("gameConfig.preview.incomplete")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Text("gameConfig.preview.winetricksNote")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }

    private func verbRow(_ verb: String) -> some View {
        HStack(spacing: 6) {
            if installedVerbs.contains(verb) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            Text(verb)
                .font(.caption)
            Spacer()
            Text(
                installedVerbs.contains(verb)
                    ? String(localized: "gameConfig.preview.winetricksInstalled")
                    : String(localized: "gameConfig.preview.winetricksMissing")
            )
            .font(.caption2)
            .foregroundStyle(installedVerbs.contains(verb) ? .green : .orange)
        }
    }
}

// MARK: - Error Banner

extension GameConfigPreviewSheet {
    @ViewBuilder
    private var errorBanner: some View {
        if let error = applyError {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding(8)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Footer

extension GameConfigPreviewSheet {
    private var sheetFooter: some View {
        HStack {
            Toggle("gameConfig.preview.dontShowAgain", isOn: $skipPreview)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("gameConfig.preview.cancel", role: .cancel) {
                dismiss()
            }
            // Cancelling mid-apply would leave the settings written but skip the
            // dependency install and the toast, so there is nothing to cancel
            // once the work has started.
            .disabled(isApplying)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("gamedb.preview.cancelButton")

            Button("gameConfig.preview.applyButton") {
                Task {
                    await applyConfiguration()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isApplying)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("gamedb.preview.applyButton")
        }
        .padding()
        .background(.bar)
    }
}

// MARK: - Data Loading

extension GameConfigPreviewSheet {
    private func loadPreviewData() async {
        // Load preview changes
        changes = GameConfigApplicator.previewChanges(variant: variant, bottle: bottle)

        // Check staleness
        if let testedWith = variant.testedWith {
            stalenessResult = StalenessChecker.check(testedWith: testedWith)
        }

        await scanInstalledVerbs()
    }

    /// Resolves what the bottle already has, and from that what is still missing.
    private func scanInstalledVerbs() async {
        let result = await Winetricks.loadInstalledVerbs(for: bottle)
        installedVerbs = result.verbs
        missingDependency = GameConfigDependency.pendingInstall(
            entry: entry,
            variant: variant,
            installedVerbs: result.verbs
        )
        didScanVerbs = true
    }
}

// MARK: - Apply Action

extension GameConfigPreviewSheet {
    private func applyConfiguration() async {
        isApplying = true
        applyError = nil

        // The scan behind `missingDependency` can shell out to winetricks, and
        // Apply is clickable while it runs. Applying on a half-loaded preview
        // would silently skip the install, so wait for it -- but only when this
        // variant asks for verbs at all, so presets without them never block.
        if includeWinetricks, !didScanVerbs, !(variant.winetricksVerbs ?? []).isEmpty {
            await scanInstalledVerbs()
        }

        do {
            // The snapshot is written to the bottle directory for a future revert.
            _ = try GameConfigApplicator.apply(
                entry: entry,
                variant: variant,
                to: bottle,
                programURL: programURL
            )

            // Applying is immediate: kill the bottle's processes so nothing
            // keeps running on the old settings.
            guard includeWinetricks, let pending = missingDependency else {
                Wine.killBottle(bottle: bottle)
                finish()
                return
            }

            // Install first, restart after: the bottle has to come back up on
            // the new settings *and* the newly installed components, and
            // winetricks needs its own wineserver while it works.
            installing = pending
        } catch {
            applyError = String(localized: "gameConfig.apply.failed \(error.localizedDescription)")
            isApplying = false
        }
    }

    /// Closes the preview and reports the applied configuration.
    ///
    /// Also runs as the install sheet's `onDismiss`, whether the verbs installed,
    /// failed, or the user cancelled out: the settings landed either way, and the
    /// install sheet reports the verb outcome itself.
    /// Called when the install sheet closes: the components are in, so restart
    /// the bottle now and report success.
    private func finishAfterInstall() {
        Task {
            await Wine.killBottleAndWait(bottle: bottle)
            finish()
        }
    }

    private func finish() {
        dismiss()
        toast = ToastData(
            message: String(localized: "gameConfig.apply.success \(entry.title)"),
            style: .success
        )
    }
}
