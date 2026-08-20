//
//  NCNotice.swift
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

/// Something the app needs to tell you about the thing you are looking at, and
/// optionally the one control that answers it.
///
/// The app had around twenty-five of these written by hand — bare icon and
/// caption pairs, tinted banners, red `Label`s, coloured rounded rectangles,
/// warnings smuggled into a `Toggle`'s own label. Each picked its own severity,
/// so a note you could ignore and a note that blocked you looked equally loud.
/// Here the severity is declared once, as an `NCStatus`, and the tint and glyph
/// follow from it.
struct NCNotice<Action: View>: View {
    /// Drives the tint and, unless `symbol` overrides it, the glyph.
    let status: NCStatus
    /// The prose. A `String`, not a `LocalizedStringKey`, because most of these
    /// interpolate a runtime value — a bottle name, a path, a count — and a key
    /// built by interpolation looks up a table entry that does not exist and
    /// silently falls back to English. Callers with fixed wording pass
    /// `String(localized:)` themselves.
    let message: String
    /// An optional bold first line. Fixed wording by definition, so a key.
    var title: LocalizedStringKey?
    /// Overrides `status.symbol` where the subject has a glyph of its own — a
    /// disk, a bottle, a network — and the tint alone carries the severity.
    var symbol: String?
    /// The one control the notice is asking for: Stop Bottle, Install…, Reveal.
    @ViewBuilder var action: Action

    /// Enough tint to group the notice against the surface behind it, not
    /// enough to make it a card. Notices carry no border for the same reason.
    private static var backgroundOpacity: Double {
        0.10
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
            Image(systemName: symbol ?? status.symbol)
                .font(Theme.Typography.rowCaption)
                .foregroundStyle(status.tint)
                // Decorative: the severity is already in the words, and an
                // unlabelled glyph read aloud is noise.
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                if let title {
                    Text(title)
                        .font(Theme.Typography.sectionTitle)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Notices explain rather than name, so this wraps to as many
                // lines as it needs. Nothing here is ever truncated.
                Text(message)
                    .font(Theme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Space.snug)
            action
                .controlSize(.small)
        }
        .padding(Theme.Space.row)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.tint.opacity(Self.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

/// A notice that only reports — the common case.
///
/// Swift has no default generic arguments, so without this every plain notice
/// would have to spell `action: { EmptyView() }` and read like an omission.
extension NCNotice where Action == EmptyView {
    init(
        status: NCStatus,
        message: String,
        title: LocalizedStringKey? = nil,
        symbol: String? = nil
    ) {
        self.init(
            status: status,
            message: message,
            title: title,
            symbol: symbol,
            action: { EmptyView() }
        )
    }
}
