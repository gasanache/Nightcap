//
//  NCSection.swift
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

/// The header line of a section: what the group is, and the one control that
/// acts on the whole group.
///
/// Bottle Configuration grew four ways of writing this — a plain `Text`, a
/// `Label` with a button pushed over by a `Spacer`, and two kinds of `VStack`
/// wearing `.font(.headline)` and pretending. This is the one way.
///
/// It deliberately sets no font. A section header is styled by the `Form` or
/// `List` it sits in, and every hand-rolled `.headline` on a header is what let
/// sub-titles inside a section outrank the header above them.
struct NCSectionHeader<Accessory: View>: View {
    /// A fixed label written in code, so it is a key rather than a `String`.
    let title: LocalizedStringKey
    var systemImage: String?
    /// The control that acts on the section as a whole: a refresh, an add, a
    /// count of what is inside.
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: Theme.Space.snug) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
            Spacer(minLength: Theme.Space.snug)
            accessory
        }
    }
}

// Swift has no default generic arguments, so a header with nothing trailing it
// would have to spell `accessory: { EmptyView() }`. Most headers are just a
// title.
extension NCSectionHeader where Accessory == EmptyView {
    init(title: LocalizedStringKey, systemImage: String? = nil) {
        self.init(title: title, systemImage: systemImage, accessory: { EmptyView() })
    }
}

/// A real `Section`, with its header already built.
///
/// Callers were hand-rolling the `header:` closure every time, which is where
/// the four competing header idioms came from. Asking for a title here means
/// the header cannot drift again.
struct NCSection<Content: View, Accessory: View>: View {
    let title: LocalizedStringKey
    var systemImage: String?
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        Section {
            content
        } header: {
            NCSectionHeader(title: title, systemImage: systemImage) {
                accessory
            }
        }
    }
}

// The two-slot form, for the common section whose header carries no control.
extension NCSection where Accessory == EmptyView {
    init(
        title: LocalizedStringKey,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            accessory: { EmptyView() },
            content: content
        )
    }
}

/// The name of a group *inside* a section.
///
/// Ranked below the section header on purpose: `sectionTitle` is a semibold
/// subheadline, where the `.headline` labels this replaces were larger than the
/// header they sat under, so the nesting read upside down.
struct NCGroupLabel: View {
    /// Fixed label, so a key. A runtime name — a bottle, a filename — belongs in
    /// the group's content as a `String`, not here.
    let title: LocalizedStringKey
    var systemImage: String?

    var body: some View {
        Group {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .font(Theme.Typography.sectionTitle)
        .foregroundStyle(.secondary)
    }
}

/// A named group inside a section: an `NCGroupLabel` and the rows it owns.
///
/// The app currently separates these with bare `Divider()` calls, which is the
/// only place it draws rules — the top padding here does the same job by
/// grouping rather than by cutting.
struct NCSubsection<Content: View>: View {
    let title: LocalizedStringKey
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            NCGroupLabel(title: title, systemImage: systemImage)
            content
        }
        .padding(.top, Theme.Space.snug)
    }
}
