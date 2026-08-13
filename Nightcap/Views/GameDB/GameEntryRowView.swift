//
//  GameEntryRowView.swift
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

/// A row in the preset list.
///
/// A preset is a set of changes waiting to be applied, so the row carries only
/// what distinguishes one from another: its name, what it is for, and the
/// backend it selects. Status is a single dot rather than a filled capsule —
/// with a handful of presets on screen, coloured pills read as noise and the
/// eye stops finding the names.
struct GameEntryRowView: View {
    let entry: GameDBEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                .accessibilityLabel(entry.rating.displayName)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(.body, weight: .semibold))
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            if let backend = backendLabel {
                // Monospaced: these are machine values, and the column of them
                // reads as a column when the digits and glyphs line up.
                Text(backend)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        switch entry.rating {
        case .works: .green
        case .playable: .orange
        case .unverified: .secondary
        case .broken, .notSupported: .red
        }
    }

    /// The backend the preset selects, or nil when it leaves graphics alone.
    private var backendLabel: String? {
        switch entry.defaultVariant?.settings.graphicsBackend {
        case .d3dMetal: "D3DMetal"
        case .dxvk: "DXVK"
        case .dxmt: "DXMT"
        case .wined3d: "WineD3D"
        case .recommended, .none: nil
        }
    }
}
