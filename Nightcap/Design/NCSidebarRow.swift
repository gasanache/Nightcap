//
//  NCSidebarRow.swift
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

/// How far a row recedes when it is present but not currently usable.
///
/// One value, named once. The sidebar had three — 0.5, 0.6, and a third 0.5 on a
/// branch nothing routed to — so two greyed-out bottles could grey out by
/// different amounts.
private let ncSidebarDimmedOpacity: Double = 0.5

/// A bottle in the sidebar: what it is called, how it is doing, and what is
/// happening to it right now.
///
/// The sidebar drew three mutually exclusive row shapes — two written inline in
/// `ContentView`, one in a file of its own — with three layouts and three
/// opacities between them, and one of them marked an unavailable bottle with a
/// raw orange `exclamationmark.triangle.fill` instead of `NCStatus.missing`.
/// This is the single shape: status, name, caption, then the trailing state.
///
/// The trailing slot is ordered count, then spinner, then accessory, and the
/// order never varies. A row that starts working should not shuffle the things
/// beside it.
struct NCSidebarRow<Accessory: View>: View {
    /// A bottle name — chosen by the user at runtime, so `String`. Passing this
    /// as a `LocalizedStringKey` would look the name up in the string table and
    /// quietly render whatever came back.
    let title: String
    /// The leading glyph. Nil draws none, for a row that is only a name.
    var status: NCStatus?
    /// Runtime detail — a Windows version, a last-used date. `String` for the
    /// same reason as `title`.
    var caption: String?
    var isBusy: Bool = false
    /// Drawn by `NCCountBadge`, which renders nothing at zero, so callers can
    /// pass a live count without guarding it.
    var badgeCount: Int?
    var isDimmed: Bool = false
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
            if let status {
                Image(systemName: status.symbol)
                    // Caption-sized to match NCStatusBadge, so the same state is
                    // the same size wherever you meet it.
                    .font(Theme.Typography.rowCaption)
                    .foregroundStyle(status.tint)
                    .accessibilityLabel(Self.accessibilityLabel(for: status))
            }
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(title)
                    .font(Theme.Typography.rowTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let caption {
                    Text(caption)
                        .font(Theme.Typography.rowCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: Theme.Space.snug)
            trailing
        }
        .padding(.vertical, Theme.Space.tight)
        .opacity(isDimmed ? ncSidebarDimmedOpacity : 1)
    }

    private var trailing: some View {
        HStack(spacing: Theme.Space.snug) {
            if let badgeCount {
                // Untinted: the count describes what is inside the bottle, not
                // what state the bottle is in, so it does not borrow the status
                // colour and compete with the glyph.
                NCCountBadge(count: badgeCount, tint: nil)
            }
            if isBusy {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            }
            accessory
        }
    }

    /// Fixed English source text, so `LocalizedStringKey` — these are real keys
    /// in the string table, unlike `title` and `caption`.
    ///
    /// The glyph is the only thing carrying the state here, since a sidebar row
    /// has no room for the written label `NCStatusBadge` shows.
    private static func accessibilityLabel(for status: NCStatus) -> LocalizedStringKey {
        switch status {
        case .ready: "status.ready"
        case .available: "status.available"
        case .missing: "status.missing"
        case .running: "status.running"
        case .failed: "status.failed"
        case .unknown: "status.unknown"
        }
    }
}

extension NCSidebarRow where Accessory == EmptyView {
    /// A row with no trailing control, which is most of them — the row is the
    /// control.
    ///
    /// Swift has no default generic arguments, so without this every such call
    /// site would have to spell `accessory: { EmptyView() }`.
    init(
        title: String,
        status: NCStatus? = nil,
        caption: String? = nil,
        isBusy: Bool = false,
        badgeCount: Int? = nil,
        isDimmed: Bool = false
    ) {
        self.init(
            title: title,
            status: status,
            caption: caption,
            isBusy: isBusy,
            badgeCount: badgeCount,
            isDimmed: isDimmed,
            accessory: { EmptyView() }
        )
    }
}
