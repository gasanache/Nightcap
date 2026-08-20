//
//  NCCards.swift
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

import AppKit
import SwiftUI

/// The few numbers a card is made of that `Theme` deliberately does not name.
///
/// `Theme` names spacing, radii and type roles — the vocabulary every screen
/// shares. Border weight and fill strength are not that; they are internal to
/// how a card is drawn. They live here once so the cards agree with each other
/// without widening the shared vocabulary.
private enum CardMetric {
    /// How far the fill lifts off the window background.
    static let fillOpacity: Double = 0.4
    /// A card describing something unavailable. Dimmed, still readable.
    static let mutedOpacity: Double = 0.65
    /// The resting border.
    static let border: CGFloat = 1
    /// The selected border. Doubled rather than recoloured alone, so selection
    /// still reads when the tint is close to the separator.
    static let selectedBorder: CGFloat = 2
    /// A pinned-program tile, square, matching the grid's minimum column width
    /// so columns stop drifting as the window resizes.
    static let tileSide: CGFloat = 100
    /// How far a tile's icon swells as it launches, on its way out.
    static let openingScale: CGFloat = 2
}

/// A bordered container, one shape, everywhere.
///
/// The app had eight card geometries — different paddings, three different
/// radii, borders that were sometimes a stroke and sometimes a shadow — so two
/// cards on the same screen could disagree about what a card is.
///
/// Selection is a heavier tinted border, not a filled accent block with forced
/// white text. One screen does the latter today; it is the only one, and it is
/// unreadable in dark mode.
struct NCCard<Content: View>: View {
    var isSelected: Bool = false
    /// For a card describing something the user cannot have: an unsupported
    /// option, a component that is not installed.
    var isMuted: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.Space.card)
            .background(.quaternary.opacity(CardMetric.fillOpacity))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        borderStyle,
                        lineWidth: isSelected ? CardMetric.selectedBorder : CardMetric.border
                    )
            }
            .opacity(isMuted ? CardMetric.mutedOpacity : 1)
    }

    /// `.tint` and `.separator` are different `ShapeStyle` types, so the two
    /// branches only share a type once both are erased — the same dance
    /// `NCEmptyState` does for its glyph.
    private var borderStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator)
    }
}

/// A choice you can pick, where the whole card is the button.
///
/// Built on `NCCard`, wrapped in a plain-styled `Button` so the hit target is
/// the card rather than a small control inside it, and so the choice is
/// reachable by keyboard — several of the app's pickable cards are tap
/// gestures today and cannot be focused at all.
///
/// `isAvailable: false` disables the button *and* mutes the card. That pairing
/// is the point: the app has a number of controls that look actionable and
/// silently do nothing, and this is how they stop lying.
struct NCOptionCard<Accessory: View>: View {
    // Keys, not `String`s: these are fixed labels written at the call site, so
    // they belong in the strings catalogue.
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var systemImage: String?
    var isAvailable: Bool = true
    let action: () -> Void
    /// A trailing control that belongs to the choice: a version stepper, a
    /// status badge, a disclosure.
    @ViewBuilder var accessory: Accessory

    var body: some View {
        Button(action: action) {
            NCCard(isMuted: !isAvailable) {
                HStack(alignment: .top, spacing: Theme.Space.row) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(Theme.Typography.rowTitle)
                            .imageScale(.large)
                            .foregroundStyle(isAvailable ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    }
                    VStack(alignment: .leading, spacing: Theme.Space.tight) {
                        Text(title)
                            .font(Theme.Typography.rowTitle)
                        Text(detail)
                            .font(Theme.Typography.rowCaption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: Theme.Space.snug)
                    accessory
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .accessibilityElement(children: .combine)
    }
}

// Most option cards carry nothing on the trailing edge, and spelling
// `accessory: { EmptyView() }` at those call sites reads like an oversight.
extension NCOptionCard where Accessory == EmptyView {
    init(
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        systemImage: String? = nil,
        isAvailable: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(
            title: title,
            detail: detail,
            systemImage: systemImage,
            isAvailable: isAvailable,
            action: action,
            accessory: { EmptyView() }
        )
    }
}

/// One pinned program in the grid.
///
/// The tile it replaces hardcoded 90x90 inside a grid whose columns were a
/// minimum of 100, so the gaps between pins shifted every time the window was
/// resized, and it hung its icon and its running marker off further unrelated
/// literals — 45, 16, a 12pt `EdgeInsets` nudge. Here the tile is one constant
/// and everything else is derived from it.
///
/// It also launched on `.onTapGesture(count: 2)` and nothing else: no keyboard
/// route, no focus ring, no accessibility identifier. A tile that starts
/// something keeps the double click — brushing past a pin should not launch a
/// game — but gains focus, Return, Space and a VoiceOver action alongside it.
struct NCTile: View {
    /// A program name read off the filesystem — a runtime value, so `String`.
    /// Wrapping it in a `LocalizedStringKey` would look up a key that does not
    /// exist and quietly render the fallback.
    let title: String
    var systemImage: String?
    /// Program icons are extracted from the executable, so they arrive as
    /// `NSImage` rather than as an asset name.
    var nsImage: NSImage?
    /// `nil` draws no marker. `.running` draws the live one.
    var status: NCStatus?
    /// The tile has been pressed and the program is on its way up. The icon
    /// swells and fades, so the press has a visible consequence while the
    /// launch takes its second. The caller owns the flag and animates it — the
    /// tile only says what the two ends look like.
    var isOpening: Bool = false
    /// An identifier the caller has already established, e.g. one UI tests
    /// look for. An identifier set inside a view wins over one applied around
    /// it, so an override has to arrive as a value rather than as a modifier.
    var accessibilityID: String?
    /// Requires a double click from the pointer, the way a Finder icon does.
    /// Launching a game by brushing past it is worse than one extra click, so
    /// tiles that start something set this. Keyboard and VoiceOver still
    /// activate on a single Return either way.
    var requiresDoubleClick: Bool = false
    let action: () -> Void

    /// Derived from the tile, not chosen separately: half the tile, less the
    /// gap it needs from the label beneath it.
    private var iconSide: CGFloat {
        CardMetric.tileSide / 2 - Theme.Space.snug
    }

    var body: some View {
        // Two different controls, not one control with a disabled action.
        //
        // The first attempt kept the Button and handed it an empty closure when
        // a double click was required — so a focused tile activated on Return
        // and did nothing, which is worse than the bare gesture it replaced.
        // A double-click tile is therefore built from the pieces a Button would
        // have given it: focusable, Return and Space activate, and it reports
        // itself as a button to VoiceOver.
        if requiresDoubleClick {
            tile
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                .focusable()
                .onTapGesture(count: 2, perform: action)
                .onKeyPress(.return) { action()
                    return .handled
                }
                .onKeyPress(.space) { action()
                    return .handled
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default, action)
                .accessibilityLabel(Text(title))
                .accessibilityIdentifier(accessibilityID ?? "tile.\(title)")
        } else {
            Button(action: action) { tile }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(title))
                .accessibilityIdentifier(accessibilityID ?? "tile.\(title)")
        }
    }

    private var tile: some View {
        VStack(spacing: Theme.Space.tight) {
            icon
                .frame(width: iconSide, height: iconSide)
                .scaleEffect(isOpening ? CardMetric.openingScale : 1)
                .opacity(isOpening ? 0 : 1)
            Spacer(minLength: 0)
            Text(title)
                .font(Theme.Typography.rowCaption)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.middle)
        }
        .padding(Theme.Space.snug)
        .frame(width: CardMetric.tileSide, height: CardMetric.tileSide)
        .overlay(alignment: .bottomTrailing) {
            marker
        }
        // The whole square is the target, including the empty part above
        // the label.
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        // VoiceOver and Return activate on one press regardless, so the
        // double-click requirement never reaches assistive technology.
        .accessibilityAction(.default, action)
    }

    private var icon: some View {
        Group {
            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
            } else {
                Image(systemName: systemImage ?? "app.dashed")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .scaledToFit()
    }

    @ViewBuilder
    private var marker: some View {
        if let status {
            Image(systemName: status.symbol)
                .font(Theme.Typography.detail)
                .foregroundStyle(status.tint)
                .padding(Theme.Space.tight)
                // The glyph alone has no words for the state — `NCStatusBadge`
                // is where a status gets a label — so it stays out of the
                // accessibility tree rather than reading as "circle".
                .accessibilityHidden(true)
        }
    }
}
