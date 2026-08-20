//
//  NCBadges.swift
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

/// A tally, or nothing at all.
///
/// The app draws two count badges today and one of them is permanently zero,
/// because the decision "is there anything to report?" was left to the caller
/// and one caller forgot to make it. This one disappears on its own when
/// `count` is zero or less, so a call site hands it a number unconditionally
/// and stops wrapping it in a check.
struct NCCountBadge: View {
    let count: Int
    /// Tints the pill when the tally carries a state — bottles running, installs
    /// failed. Left nil it stays `.secondary`, which is right for a plain count.
    var tint: Color?

    /// Enough fill to read as a pill, not enough to compete with the number.
    private static let fillOpacity = 0.18

    private var colour: Color {
        tint ?? .secondary
    }

    var body: some View {
        if count > 0 {
            // `Text(_:format:)` rather than `Text("\(count)")`: the count is a
            // runtime value, so it must not go near LocalizedStringKey, and
            // `.number` gives the reader their own digits and grouping.
            Text(count, format: .number)
                // Monospaced digits so a badge counting up or down does not
                // twitch as the glyph widths change.
                .font(Theme.Typography.detail.monospacedDigit())
                .foregroundStyle(colour)
                .padding(.horizontal, Theme.Space.snug)
                .padding(.vertical, Theme.Space.tight)
                .background(colour.opacity(Self.fillOpacity))
                .clipShape(Capsule())
        }
    }
}

/// One line of a requirements checklist: met, or not yet.
///
/// The Settings engine section grew a private `checklistLine` that reached into
/// `NCStatus.symbol` and `NCStatus.tint` itself rather than going through the
/// badge, which is how a checkmark in one place drifts from a checkmark
/// everywhere else. The status lookup happens here, once.
struct NCChecklistRow: View {
    /// A key rather than a `String`: a checklist item is written into the app,
    /// never read back off the machine, so it can and should be translated.
    let text: LocalizedStringKey
    let isDone: Bool
    /// Why the item is or is not met — fixed prose, so also a key. A runtime
    /// value such as a path or a version belongs in `NCRow`'s `machine`.
    var detail: LocalizedStringKey?

    private var status: NCStatus {
        isDone ? .ready : .missing
    }

    /// VoiceOver reads the glyph, which is otherwise a silent picture, and the
    /// row combines it with the text into one utterance.
    private var glyphLabel: LocalizedStringKey {
        isDone ? "Met" : "Not met"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
            Image(systemName: status.symbol)
                .foregroundStyle(status.tint)
                .accessibilityLabel(glyphLabel)
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                // Matches `NCStatusBadge`, the nearest relative: a glyph and a
                // short label describing one component's state.
                Text(text)
                    .font(Theme.Typography.rowCaption)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(Theme.Typography.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        // Fills the width so a column of these aligns on the glyph rather than
        // centring itself in whatever the parent gives it.
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
