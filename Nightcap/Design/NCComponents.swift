//
//  NCComponents.swift
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

import SwiftUI

/// The one status marker, so "installed" looks the same in Settings, in Bottle
/// Configuration and in the setup wizard.
struct NCStatusBadge: View {
    let status: NCStatus
    let label: LocalizedStringKey
    var body: some View {
        Label {
            Text(label)
        } icon: {
            Image(systemName: status.symbol)
        }
        .font(Theme.Typography.rowCaption)
        .foregroundStyle(status.tint)
        .labelStyle(.titleAndIcon)
        .accessibilityLabel(label)
    }
}

/// One thing, what it is, and what you can do about it.
///
/// The shape every list in the app was reaching for by hand: a subject, a line
/// of prose under it, optional machine-readable detail, and a trailing status
/// or control.
struct NCRow<Accessory: View>: View {
    let title: String
    var caption: String?
    /// Machine-readable detail — a path, a verb list, a version.
    var machine: String?
    var isMachineTitle: Bool = false
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.row) {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(title)
                    .font(isMachineTitle ? Theme.Typography.machineTitle : Theme.Typography.rowTitle)
                if let caption {
                    Text(caption)
                        .font(Theme.Typography.rowCaption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let machine {
                    // Middle-truncated because these are paths and filenames,
                    // where both ends carry the meaning. Prose belongs in
                    // `caption`, which wraps.
                    Text(machine)
                        .font(Theme.Typography.machine)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: Theme.Space.snug)
            accessory
        }
        .padding(.vertical, Theme.Space.snug)
    }
}

/// Nothing here yet, and what to do about it.
///
/// An empty screen is an invitation to act, so it always carries the action
/// rather than only reporting the absence.
struct NCEmptyState<Action: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    var message: LocalizedStringKey?
    /// Tints the glyph when the absence itself carries a state — a failed
    /// probe, a disconnected device. Left nil the glyph stays quiet, which is
    /// right for "nothing here yet".
    var symbolTint: Color?
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: Theme.Space.row) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                // `.tertiary` is a ShapeStyle rather than a Color, so the two
                // branches only share a type once both are erased.
                .foregroundStyle(symbolTint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.tertiary))
            VStack(spacing: Theme.Space.tight) {
                Text(title)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if let message {
                    Text(message)
                        .font(Theme.Typography.rowCaption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }
            action
        }
        // Fills whatever it is given, so where it lands is deliberate rather
        // than left to the parent.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// An empty state that genuinely has nothing to offer — a filtered list with no
// matches, where the way out is to change the filter, not to press anything
// here. Spelling `{ EmptyView() }` at those call sites reads like an oversight.
extension NCEmptyState where Action == EmptyView {
    init(
        systemImage: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        symbolTint: Color? = nil
    ) {
        self.init(
            systemImage: systemImage,
            title: title,
            message: message,
            symbolTint: symbolTint,
            action: { EmptyView() }
        )
    }
}
