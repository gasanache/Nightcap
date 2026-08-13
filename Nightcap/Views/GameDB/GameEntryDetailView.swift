// swiftlint:disable file_length
//
//  GameEntryDetailView.swift
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

/// The detail view for a game database entry, showing all 6 content sections:
/// At a Glance, Recommended Configuration, Variants, What It Changes,
/// Notes / Known Issues, and Provenance.
struct GameEntryDetailView: View {
    let entry: GameDBEntry
    @ObservedObject var bottle: Bottle
    @State private var selectedVariant: GameConfigVariant?
    @State private var showPreviewSheet: Bool = false
    @State private var stalenessResult: StalenessResult?
    @State private var toast: ToastData?

    var body: some View {
        ScrollView {
            Form {
                atAGlanceSection
                recommendedConfigSection
                variantsSection
                whatItChangesSection
                notesAndIssuesSection
            }
            .formStyle(.grouped)
        }
        .navigationTitle(entry.title)
        .toast($toast)
        .sheet(isPresented: $showPreviewSheet) {
            if let variant = selectedVariant {
                GameConfigPreviewSheet(
                    entry: entry,
                    variant: variant,
                    bottle: bottle,
                    programURL: nil,
                    toast: $toast
                )
            }
        }
        .onAppear {
            if selectedVariant == nil {
                selectedVariant = entry.defaultVariant
            }
            if let variant = selectedVariant, let testedWith = variant.testedWith {
                stalenessResult = StalenessChecker.check(testedWith: testedWith)
            }
        }
        .onChange(of: selectedVariant?.id) { _, _ in
            if let variant = selectedVariant, let testedWith = variant.testedWith {
                stalenessResult = StalenessChecker.check(testedWith: testedWith)
            } else {
                stalenessResult = nil
            }
        }
    }
}

// MARK: - Section 1: At a Glance

extension GameEntryDetailView {
    private var atAGlanceSection: some View {
        Section("gameConfig.detail.atAGlance") {
            ratingRow
            if let constraints = entry.constraints {
                constraintTags(constraints)
            }
            antiCheatRow
            stalenessWarningBanner
        }
    }

    private var ratingRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ratingColor)
                .frame(width: 7, height: 7)
            Text(entry.rating.displayName)
                .font(.system(.body, weight: .semibold))
            Spacer()
            if let subtitle = entry.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Requirements as one quiet line.
    ///
    /// These are the app's own floors and read the same on every preset, so a
    /// row of icon chips repeating them four times is noise. One monospaced
    /// line keeps the fact available without competing with the preset.
    private func constraintTags(_ constraints: GameConstraints) -> some View {
        HStack(spacing: 6) {
            Text("gameConfig.detail.requires")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(requirementSummary(constraints))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func requirementSummary(_ constraints: GameConstraints) -> String {
        var parts: [String] = []
        if let architectures = constraints.cpuArchitectures, !architectures.isEmpty {
            parts.append(architectures.joined(separator: "/"))
        }
        if let minMacOS = constraints.minMacOSVersion {
            parts.append("macOS \(minMacOS)+")
        }
        if let minWine = constraints.minWineVersion {
            parts.append("Wine \(minWine)+")
        }
        return parts.joined(separator: "  ·  ")
    }

    @ViewBuilder
    private var antiCheatRow: some View {
        if let antiCheat = entry.antiCheat {
            HStack(spacing: 6) {
                Image(systemName: "shield.slash")
                    .foregroundStyle(.orange)
                Text("\(antiCheat) -- online play unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var stalenessWarningBanner: some View {
        if let result = stalenessResult, result.isStale, let message = result.warningMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var ratingColor: Color {
        switch entry.rating {
        case .works: .green
        case .playable: .yellow
        case .unverified: .gray
        case .broken: .red
        case .notSupported: .red
        }
    }
}

// MARK: - Section 2: Recommended Configuration

extension GameEntryDetailView {
    private var recommendedConfigSection: some View {
        Section("gameConfig.detail.recommendedConfig") {
            if let variant = selectedVariant {
                recommendedContent(variant)
            } else {
                Text("gameConfig.detail.noVariant")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func recommendedContent(_ variant: GameConfigVariant) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(variant.label)
                    .font(.system(.title3, weight: .semibold))
                if let whenToUse = variant.whenToUse {
                    Text(whenToUse)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let rationale = variant.rationale, !rationale.isEmpty {
                // Reasons sit behind a rule rather than bullets: each is a
                // sentence of argument, not an item in a list.
                HStack(alignment: .top, spacing: 10) {
                    Rectangle()
                        .fill(.tint.opacity(0.5))
                        .frame(width: 2)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(rationale, id: \.self) { point in
                            Text(point)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineSpacing(1.5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 1)
            }

            HStack {
                Spacer()
                Button {
                    showPreviewSheet = true
                } label: {
                    Text("gameConfig.detail.applyTo \(bottle.settings.name)")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("gamedb.detail.applyButton")
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Section 3: Variants

extension GameEntryDetailView {
    @ViewBuilder
    private var variantsSection: some View {
        if entry.variants.count > 1 {
            Section("gameConfig.detail.variants") {
                GameVariantPickerView(
                    variants: entry.variants,
                    selected: $selectedVariant
                )
            }
        }
    }
}

// MARK: - Section 4: What It Changes

extension GameEntryDetailView {
    @ViewBuilder
    private var whatItChangesSection: some View {
        if let variant = selectedVariant {
            Section("gameConfig.detail.whatItChanges") {
                settingsByArea(variant)
            }
        }
    }

    @ViewBuilder
    private func settingsByArea(_ variant: GameConfigVariant) -> some View {
        settingsAreaGraphics(variant.settings)
        settingsAreaPerformance(variant.settings)
        settingsAreaDLLOverrides(variant)
        settingsAreaWinetricks(variant)
        settingsAreaEnvironment(variant)
    }

    @ViewBuilder
    private func settingsAreaGraphics(_ settings: GameConfigVariantSettings) -> some View {
        let items = graphicsSettingsList(settings)
        if !items.isEmpty {
            settingsGroup(String(localized: "gameConfig.detail.graphics"), items: items)
        }
    }

    @ViewBuilder
    private func settingsAreaPerformance(_ settings: GameConfigVariantSettings) -> some View {
        let items = performanceSettingsList(settings)
        if !items.isEmpty {
            settingsGroup(String(localized: "gameConfig.detail.performance"), items: items)
        }
    }

    @ViewBuilder
    private func settingsAreaDLLOverrides(_ variant: GameConfigVariant) -> some View {
        if let overrides = variant.dllOverrides, !overrides.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("gameConfig.detail.dllOverrides")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                ForEach(overrides, id: \.dllName) { override in
                    settingRow(name: override.dllName, value: override.mode.displayName)
                }
            }
        }
    }

    @ViewBuilder
    private func settingsAreaWinetricks(_ variant: GameConfigVariant) -> some View {
        if let verbs = variant.winetricksVerbs, !verbs.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("gameConfig.detail.winetricks")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                ForEach(verbs, id: \.self) { verb in
                    settingRow(name: verb, value: String(localized: "gameConfig.detail.required"))
                }
            }
        }
    }

    @ViewBuilder
    private func settingsAreaEnvironment(_ variant: GameConfigVariant) -> some View {
        if let envVars = variant.environmentVariables, !envVars.isEmpty {
            DisclosureGroup("gameConfig.detail.showAdvanced") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(envVars.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        settingRow(name: key, value: value)
                    }
                }
            }
            .font(.subheadline)
        }
    }

    private func settingsGroup(_ title: String, items: [SettingDisplay]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // An eyebrow rather than a heading: these group names label a
            // column of values, they are not sections competing with the
            // page title.
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 6)

            ForEach(Array(items.enumerated()), id: \.element.name) { index, setting in
                if index > 0 {
                    Divider().opacity(0.4)
                }
                settingRow(name: setting.name, value: setting.value)
            }
        }
        .padding(.vertical, 2)
    }

    private func settingRow(name: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 5)
    }

    private func graphicsSettingsList(_ settings: GameConfigVariantSettings) -> [SettingDisplay] {
        var items: [SettingDisplay] = []
        if let backend = settings.graphicsBackend {
            items.append(SettingDisplay(name: "Graphics Backend", value: backend.displayName))
        }
        if let dxvk = settings.dxvk {
            items.append(SettingDisplay(name: "DXVK", value: dxvk ? "Enabled" : "Disabled"))
        }
        if let dxvkAsync = settings.dxvkAsync {
            items.append(SettingDisplay(name: "DXVK Async", value: dxvkAsync ? "Enabled" : "Disabled"))
        }
        if let sequoia = settings.sequoiaCompatMode {
            items.append(SettingDisplay(
                name: "Sequoia Compat",
                value: sequoia ? "Enabled" : "Disabled"
            ))
        }
        return items
    }

    private func performanceSettingsList(_ settings: GameConfigVariantSettings) -> [SettingDisplay] {
        var items: [SettingDisplay] = []
        if let enhancedSync = settings.enhancedSync {
            let syncName = switch enhancedSync {
            case .none: "None"
            case .esync: "ESync"
            case .msync: "MSync"
            }
            items.append(SettingDisplay(name: "Enhanced Sync", value: syncName))
        }
        if let forceD3D11 = settings.forceD3D11 {
            items.append(SettingDisplay(name: "Force D3D11", value: forceD3D11 ? "Enabled" : "Disabled"))
        }
        if let preset = settings.performancePreset {
            items.append(SettingDisplay(name: "Performance Preset", value: preset))
        }
        if let shaderCache = settings.shaderCacheEnabled {
            items.append(SettingDisplay(name: "Shader Cache", value: shaderCache ? "Enabled" : "Disabled"))
        }
        if let avx = settings.avxEnabled {
            items.append(SettingDisplay(name: "AVX Support", value: avx ? "Enabled" : "Disabled"))
        }
        return items
    }
}

// MARK: - Section 5: Notes / Known Issues

extension GameEntryDetailView {
    @ViewBuilder
    private var notesAndIssuesSection: some View {
        let hasNotes = !(entry.notes ?? []).isEmpty
        let hasIssues = !(entry.knownIssues ?? []).isEmpty

        if hasNotes || hasIssues {
            Section("gameConfig.detail.notes") {
                notesList
                issuesList
            }
        }
    }

    @ViewBuilder
    private var notesList: some View {
        if let notes = entry.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\u{2022}")
                            .foregroundStyle(.secondary)
                        Text(note)
                            .font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var issuesList: some View {
        if let issues = entry.knownIssues, !issues.isEmpty {
            ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let severity = issue.severity {
                            severityBadge(severity)
                        }
                        Text(issue.description)
                            .font(.caption)
                    }
                    if let workaround = issue.workaround {
                        Text("Workaround: \(workaround)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func severityBadge(_ severity: String) -> some View {
        Text(severity.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(severityColor(severity).opacity(0.15), in: Capsule())
            .foregroundStyle(severityColor(severity))
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "critical": .red
        case "major": .orange
        case "minor": .yellow
        default: .gray
        }
    }
}

// MARK: - Supporting Types

private struct SettingDisplay: Identifiable {
    let name: String
    let value: String
    var id: String {
        name
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        flowLayout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct FlowResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func flowLayout(proposal: ProposedViewSize, subviews: Subviews) -> FlowResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return FlowResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: currentY + lineHeight)
        )
    }
}

// swiftlint:enable file_length
