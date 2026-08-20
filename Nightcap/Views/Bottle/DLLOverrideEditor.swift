//
//  DLLOverrideEditor.swift
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

/// Reusable DLL override table editor with managed (read-only) display and custom (editable) entries.
///
/// Used at both bottle and program levels to display managed overrides (from DXVK toggle,
/// launcher presets) and allow editing of custom user overrides.
struct DLLOverrideEditor: View {
    /// Managed overrides (read-only display with source labels).
    let managedOverrides: [(entry: DLLOverrideEntry, source: String)]
    /// Custom overrides (editable by the user).
    @Binding var customOverrides: [DLLOverrideEntry]
    /// Warnings from DLLOverrideResolver for conflict display.
    let warnings: [DLLOverrideWarning]

    @State private var newDLLName: String = ""
    @State private var newDLLMode: DLLOverrideMode = .nativeThenBuiltin

    private var hasOverrides: Bool {
        !managedOverrides.isEmpty || !customOverrides.isEmpty
    }

    /// One container, so the editor is a single thing wherever it lands.
    ///
    /// This used to return four unwrapped siblings, which meant each of its two
    /// homes — a grouped `Form` section on the bottle, a plain `VStack` on the
    /// program — spread and spaced them differently, and the same editor looked
    /// like two different controls.
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.row) {
            if hasOverrides {
                managedSection
                customSection
            } else {
                emptyState
            }

            addRow

            // When there is nothing yet, the presets menu is the empty state's
            // own action rather than a second copy underneath it.
            if hasOverrides {
                presetsMenu
            }
        }
    }

    // MARK: - Empty State

    /// Nothing overridden, and the one press that changes that.
    ///
    /// `config.dllOverrides.placeholder` reads "No DLL overrides configured",
    /// which was being used as the *prompt of the name field* — so the box you
    /// type a DLL into announced that the list was empty. It says that here
    /// instead, where it is true.
    private var emptyState: some View {
        NCEmptyState(
            systemImage: "puzzlepiece.extension",
            title: "config.dllOverrides.placeholder",
            message: "config.dllOverrides.empty.message"
        ) {
            presetsMenu
        }
    }

    // MARK: - Managed Overrides Section

    /// Overrides the app set, which the user cannot edit.
    ///
    /// The heading was `.caption` — smaller than the body-monospaced DLL names
    /// underneath it, so the group read bottom-heavy. `NCSubsection` ranks it
    /// below the section header above and above the rows below.
    @ViewBuilder
    private var managedSection: some View {
        if !managedOverrides.isEmpty {
            NCSubsection(title: "config.dllOverrides.managed") {
                ForEach(managedOverrides, id: \.entry.dllName) { item in
                    managedRow(item)
                }
            }
        }
    }

    private func managedRow(_ item: (entry: DLLOverrideEntry, source: String)) -> some View {
        NCRow(title: item.entry.dllName, isMachineTitle: true) {
            HStack(spacing: Theme.Space.snug) {
                Text(item.entry.mode.displayName)
                    .font(Theme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
                Text(item.source)
                    .font(Theme.Typography.rowCaption)
                    .foregroundStyle(.tertiary)
                Image(systemName: "lock.fill")
                    .font(Theme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("config.dllOverrides.managed"))
            }
        }
    }

    // MARK: - Custom Overrides Section

    @ViewBuilder
    private var customSection: some View {
        if !customOverrides.isEmpty {
            NCSubsection(title: "config.dllOverrides.custom") {
                ForEach(Array(customOverrides.enumerated()), id: \.element.dllName) { index, entry in
                    customRow(index: index, entry: entry)
                }
            }
        }
    }

    /// One editable override, and — underneath it — whatever it is shadowing.
    ///
    /// The conflict used to be a yellow triangle whose entire explanation lived
    /// in a `.help()` tooltip, so it reached only people who hovered. The
    /// message is on screen now.
    private func customRow(index: Int, entry: DLLOverrideEntry) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            NCRow(title: entry.dllName, isMachineTitle: true) {
                HStack(spacing: Theme.Space.snug) {
                    Picker("", selection: modeBinding(at: index)) {
                        ForEach(DLLOverrideMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    Button {
                        customOverrides.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let warning = warnings.first(where: { $0.dllName == entry.dllName }) {
                NCNotice(
                    status: .missing,
                    message: warning.message,
                    symbol: "exclamationmark.triangle.fill"
                )
            }
        }
    }

    // MARK: - Add Row

    private var addRow: some View {
        HStack(spacing: Theme.Space.snug) {
            TextField("config.dllOverrides.name.placeholder", text: $newDLLName)
                .textFieldStyle(.roundedBorder)
                .font(Theme.Typography.machineTitle)
                .frame(minWidth: 120)
                .onChange(of: newDLLName) {
                    // Strip .dll suffix if the user types it
                    if newDLLName.lowercased().hasSuffix(".dll") {
                        newDLLName = String(newDLLName.dropLast(4))
                    }
                }
            Picker("", selection: $newDLLMode) {
                ForEach(DLLOverrideMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .labelsHidden()
            Button {
                addEntry()
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.plain)
            .disabled(newDLLName.trimmingCharacters(in: .whitespaces).isEmpty || entryExists(newDLLName))
        }
    }

    // MARK: - Presets Menu

    private var presetsMenu: some View {
        Menu("config.dllOverrides.presets") {
            Button("config.dllOverrides.preset.dxvk") {
                applyDXVKPreset()
            }
        }
    }
}

// MARK: - Helpers

extension DLLOverrideEditor {
    private func modeBinding(at index: Int) -> Binding<DLLOverrideMode> {
        Binding(
            get: {
                guard index < customOverrides.count else { return .nativeThenBuiltin }
                return customOverrides[index].mode
            },
            set: { newMode in
                guard index < customOverrides.count else { return }
                let entry = customOverrides[index]
                customOverrides[index] = DLLOverrideEntry(dllName: entry.dllName, mode: newMode)
            }
        )
    }

    private func entryExists(_ name: String) -> Bool {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespaces)
        return customOverrides.contains { $0.dllName == normalizedName }
            || managedOverrides.contains { $0.entry.dllName == normalizedName }
    }

    private func addEntry() {
        let name = newDLLName.lowercased().trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !entryExists(name) else { return }
        customOverrides.append(DLLOverrideEntry(dllName: name, mode: newDLLMode))
        newDLLName = ""
    }

    private func applyDXVKPreset() {
        for preset in DLLOverrideResolver.dxvkPreset {
            if let existingIndex = customOverrides.firstIndex(where: { $0.dllName == preset.dllName }) {
                customOverrides[existingIndex] = preset
            } else {
                customOverrides.append(preset)
            }
        }
    }
}
