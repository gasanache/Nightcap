//
//  GameConfigPreviewSheet+Changes.swift
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

// MARK: - Changes Section

extension GameConfigPreviewSheet {
    @ViewBuilder
    var changesSection: some View {
        if changes.isEmpty {
            Text("gameConfig.preview.noChanges")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            changesGroupedByCategory
        }
    }

    private var changesGroupedByCategory: some View {
        let grouped = Dictionary(grouping: changes, by: \.category)
        let sortedKeys = grouped.keys.sorted()

        return VStack(alignment: .leading, spacing: 12) {
            ForEach(sortedKeys, id: \.self) { category in
                if let categoryChanges = grouped[category] {
                    changeCategorySection(category, changes: categoryChanges)
                }
            }
        }
    }

    private func changeCategorySection(
        _ category: String,
        changes: [ConfigChange]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category)
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
                changeRow(change)
            }
        }
    }

    private func changeRow(_ change: ConfigChange) -> some View {
        HStack(spacing: 8) {
            if change.isHighImpact {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            Text(change.settingName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(change.currentValue)
                .font(.caption)
                .strikethrough()
                .foregroundStyle(.red.opacity(0.8))
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(change.newValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.green)
        }
    }
}

// MARK: - Restart Note

extension GameConfigPreviewSheet {
    @ViewBuilder
    var restartNote: some View {
        let hasBackendChange = changes.contains { $0.category == "Graphics" && $0.settingName == "Graphics Backend" }
        if hasBackendChange {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.blue)
                Text("gameConfig.preview.restartNote")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
