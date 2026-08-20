//
//  DesignSystem.swift
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

/// The vocabulary every screen draws from.
///
/// Before this each view chose its own spacing, type sizes and status colours,
/// so the same idea — a component being installed, a value being machine-read —
/// looked different depending on where you met it.
/// These are the shared decisions; screens compose them rather than restating
/// them.
enum Theme {
    // MARK: - Spacing

    /// One scale, used everywhere. Values between these are a mistake rather
    /// than a judgement call.
    enum Space {
        /// 4 — between a title and the caption that belongs to it.
        static let tight: CGFloat = 4
        /// 8 — between related controls in a row.
        static let snug: CGFloat = 8
        /// 12 — between rows.
        static let row: CGFloat = 12
        /// 16 — inside a card, and between cards.
        static let card: CGFloat = 16
    }

    // MARK: - Shape

    /// Two radii, because the app only ever draws two kinds of rounded thing.
    ///
    /// Before this there were five values in use across the app — 4, 6, 8, 10
    /// and 12 — chosen per view, so two cards side by side could round
    /// differently.
    enum Radius {
        /// 6 — something inline: a chip, a tag, a small well.
        static let inline: CGFloat = 6
        /// 10 — a card, a panel, anything holding rows.
        static let card: CGFloat = 10
    }

    // MARK: - Typography

    /// Eight roles, so a screen picks a role rather than a font size.
    ///
    /// `machine` is the one that carries meaning: anything the computer reads —
    /// a path, a DLL name, a winetricks verb, a version — is monospaced, so the
    /// shape of the text says whether it is prose or a value.
    ///
    /// The roles are ranked, and the rank is the point: `sectionTitle` is
    /// deliberately smaller than a section header rather than larger, because
    /// the app was full of `.headline` sub-headings that outranked the section
    /// header containing them.
    enum Typography {
        /// The name of the screen you are on.
        static let screenTitle: Font = .system(.title2, weight: .bold)
        /// A named group inside a section. Ranks *below* the section header.
        static let sectionTitle: Font = .system(.subheadline, weight: .semibold)
        /// A label above a title, e.g. "Step 2 of 3".
        static let eyebrow: Font = .system(.caption2, weight: .semibold)
        /// The subject of a row.
        static let rowTitle: Font = .system(.body, weight: .medium)
        /// What the row's subject means, in prose.
        static let rowCaption: Font = .system(.caption)
        /// Incidental detail: timestamps, counts, provenance.
        static let detail: Font = .system(.caption2)
        /// Anything the computer reads back.
        static let machine: Font = .system(.caption, design: .monospaced)
        /// Machine text where the row is the subject, e.g. a filename heading.
        static let machineTitle: Font = .system(.body, design: .monospaced)
    }
}

/// What the app is forever telling you about a component, said one way.
///
/// Every screen had its own version of this — a green checkmark here, a red
/// circle there, coloured capsules elsewhere — so the same state read
/// differently depending on where you found it.
///
/// Six states, because six is what the app actually distinguishes. The first
/// three describe a component you can obtain; the last three describe
/// something that ran.
enum NCStatus {
    /// Present and working.
    case ready
    /// Not present, but the app can get it.
    case available
    /// Not present, and it needs something from the user.
    case missing
    /// Live right now — a process, a session, a download in flight.
    case running
    /// It was attempted and it did not work.
    case failed
    /// Not determined, and not the user's fault. Never use this for "no".
    case unknown

    var symbol: String {
        switch self {
        case .ready: "checkmark.circle.fill"
        case .available: "arrow.down.circle"
        case .missing: "circle.dotted"
        case .running: "circle.fill"
        case .failed: "xmark.circle"
        case .unknown: "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .ready: .green
        case .available: .blue
        case .missing: .orange
        case .running: .green
        case .failed: .red
        case .unknown: .secondary
        }
    }
}
