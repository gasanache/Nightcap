//
//  NCRows.swift
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

/// A switch that says out loud what it does.
///
/// Twelve near-identical toggle-plus-caption stacks were written by hand, and
/// several of them put the whole explanation in a `.help()` tooltip, so a user
/// who never hovered was left guessing. The caption here is drawn on screen,
/// which is the only version of it this row offers.
///
/// Built on `Toggle` rather than a bespoke switch so the hit target, the
/// keyboard focus ring and the VoiceOver "switch" trait come from AppKit
/// instead of being approximated.
struct NCToggleRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool
    /// Fixed explanatory prose, so a key rather than a `String` — the same
    /// split `NCStatusBadge.label` makes. `NCRow.caption` is a `String` because
    /// there the caption is usually a value the app computed; here it never is.
    var caption: LocalizedStringKey?
    /// Machine-readable detail — the environment variable or registry key this
    /// switch actually writes. A runtime `String`, never a key.
    var machine: String?

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(title)
                    .font(Theme.Typography.rowTitle)
                if let caption {
                    Text(caption)
                        .font(Theme.Typography.rowCaption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let machine {
                    Text(machine)
                        .font(Theme.Typography.machine)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.vertical, Theme.Space.snug)
    }
}

/// A name and the value it currently has.
///
/// The shape of every what-this-preset-changes table and every
/// inherited-override summary, each of which had been laid out by hand with its
/// own spacing and its own idea of whether the value was monospaced.
struct NCValueRow: View {
    let name: LocalizedStringKey
    /// The value as it stands right now, so a `String`. Wrapping it in
    /// `LocalizedStringKey` would send a computed value through the string
    /// table, miss, and silently hand back the English text.
    let value: String
    /// `true` for anything the computer reads back — a path, a version, a
    /// registry value. `false` renders the value as prose, for the cases where
    /// the right-hand side is a sentence the app wrote rather than a value.
    var isMachine: Bool = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.row) {
            Text(name)
                .font(Theme.Typography.rowTitle)
            Spacer(minLength: Theme.Space.snug)
            Text(value)
                .font(isMachine ? Theme.Typography.machine : Theme.Typography.rowCaption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                // Machine values are paths and identifiers, where both ends
                // carry the meaning, so they stay on one line and lose the
                // middle. Prose is left to wrap.
                .lineLimit(isMachine ? 1 : nil)
                .truncationMode(isMachine ? .middle : .tail)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Theme.Space.tight)
    }
}

/// A row that goes somewhere.
///
/// The bottle home's five navigation rows are bare `Label`s in a grouped
/// `Form`: no caption saying what you will find on the other side, and no
/// chevron, so nothing on screen admits they are links at all. This carries the
/// caption, an optional accessory — a count, a status badge — and its own
/// chevron.
///
/// Presentation only. The destination belongs to whatever wraps this.
struct NCLinkRow<Accessory: View>: View {
    let title: LocalizedStringKey
    var caption: LocalizedStringKey?
    var systemImage: String?
    /// Sits before the chevron: a count badge, an `NCStatusBadge`.
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.row) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(Theme.Typography.rowTitle)
                    .foregroundStyle(.secondary)
                    // A fixed box so titles line up whether or not the glyph is
                    // a wide one.
                    .frame(width: Theme.Space.card, alignment: .center)
            }
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text(title)
                    .font(Theme.Typography.rowTitle)
                if let caption {
                    Text(caption)
                        .font(Theme.Typography.rowCaption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Theme.Space.snug)
            accessory
            Image(systemName: "chevron.right")
                .font(Theme.Typography.detail)
                .foregroundStyle(.tertiary)
                // Decoration. The row already reads as a link to VoiceOver by
                // way of whatever wraps it, so announcing "chevron" adds noise.
                .accessibilityHidden(true)
        }
        .padding(.vertical, Theme.Space.snug)
        // The whole row is the target, including the gap between caption and
        // chevron, rather than just the text.
        .contentShape(Rectangle())
    }
}

// Most navigation rows carry nothing but the chevron, and spelling
// `accessory: { EmptyView() }` at those call sites reads like something was
// left unfinished.
extension NCLinkRow where Accessory == EmptyView {
    init(
        title: LocalizedStringKey,
        caption: LocalizedStringKey? = nil,
        systemImage: String? = nil
    ) {
        self.init(
            title: title,
            caption: caption,
            systemImage: systemImage,
            accessory: { EmptyView() }
        )
    }
}
