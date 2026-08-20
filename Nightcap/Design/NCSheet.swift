//
//  NCSheet.swift
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

/// The chrome every sheet in the app wears.
///
/// A title and optional subtitle, a scrolling body, and one footer whose
/// buttons sit in the same place every time: anything dismissive on the left of
/// the pair, the affirmative action last, where the return key lands.
struct NCSheet<Body: View, Footer: View, Accessory: View>: View {
    let title: LocalizedStringKey
    var width: Double = ViewWidth.medium
    var height: Double = ViewHeight.medium
    /// Shown above the title, e.g. "Step 2 of 3".
    ///
    /// A key, not a `String`: typing this as `String` was why the setup
    /// wizard's step counter had to be hardcoded English.
    var eyebrow: LocalizedStringKey?
    /// 0...1 when the sheet is a step in a sequence.
    var progress: Double?
    /// A persistent list of stages down the leading edge, for a sheet that is a
    /// sequence rather than a single screen.
    var rail: AnyView?
    /// Whether the body scrolls. Off for a body that already contains its own
    /// scrolling view — a transcript, a long list — because two nested scroll
    /// views give the sheet a second scrollbar down its outer edge and make the
    /// inner one unreachable at the extremes.
    var scrolls: Bool = true
    /// Sits opposite the title: a filter, a search field, a refresh.
    @ViewBuilder var headerAccessory: Accessory
    @ViewBuilder var content: Body
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                if let rail {
                    rail
                    Divider()
                }
                if scrolls {
                    ScrollView {
                        content
                            .padding(Theme.Space.card)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    content
                        .padding(Theme.Space.card)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            Divider()
            HStack(spacing: Theme.Space.snug) {
                footer
            }
            .padding(Theme.Space.card)
        }
        .frame(width: width, height: height)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.row) {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(Theme.Typography.eyebrow)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                Text(title)
                    .font(Theme.Typography.screenTitle)
                if let progress {
                    ProgressView(value: progress, total: 1)
                        .padding(.top, Theme.Space.tight)
                }
            }
            Spacer(minLength: Theme.Space.snug)
            headerAccessory
        }
        .padding(Theme.Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Swift has no default generic arguments, so a sheet that wants no header
// accessory would have to write `headerAccessory: { EmptyView() }` at every
// call site. These give it back the two- and three-slot forms.
extension NCSheet where Accessory == EmptyView {
    init(
        title: LocalizedStringKey,
        width: Double = ViewWidth.medium,
        height: Double = ViewHeight.medium,
        eyebrow: LocalizedStringKey? = nil,
        progress: Double? = nil,
        rail: AnyView? = nil,
        scrolls: Bool = true,
        @ViewBuilder content: () -> Body,
        @ViewBuilder footer: () -> Footer
    ) {
        self.init(
            title: title,
            width: width,
            height: height,
            eyebrow: eyebrow,
            progress: progress,
            rail: rail,
            scrolls: scrolls,
            headerAccessory: { EmptyView() },
            content: content,
            footer: footer
        )
    }
}

/// Pushes what follows to the trailing edge of a sheet footer, so every sheet's
/// buttons line up in the same place.
struct NCFooterSpacer: View {
    var body: some View {
        Spacer(minLength: Theme.Space.snug)
    }
}
