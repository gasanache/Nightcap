//
//  BottomBar.swift
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

extension View {
    func bottomBar(
        @ViewBuilder content: () -> some View
    ) -> some View {
        modifier(BottomBarViewModifier(barContent: content()))
    }
}

private struct BottomBarViewModifier<BarContent: View>: ViewModifier {
    var barContent: BarContent

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                    barContent
                }
                // The pane's own background, not a material.
                //
                // `.regularMaterial` drew a grey slab — 230 grey against a pure
                // white pane in light mode — that stopped dead at the sidebar,
                // because a bar in the detail pane cannot span the window. Next
                // to the floating sidebar's rounded bottom corner that read as
                // an unfinished join rather than a bar. Matching the pane means
                // the only edge left is the Divider, which is the one that is
                // supposed to be there. Still opaque, so content scrolling
                // underneath stays hidden.
                .background(.background)
                .buttonStyle(BottomBarButtonStyle())
            }
    }
}

struct BottomBarButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.trigger()
        } label: {
            configuration.label
                .foregroundStyle(.foreground)
        }
    }
}

#Preview {
    Form {
        Text(String("Hello World"))
    }
    .formStyle(.grouped)
    .bottomBar {
        HStack {
            Spacer()
            Button {} label: {
                Text(String("Button 1"))
            }
            Button {} label: {
                Text(String("Button 2"))
            }
        }
        .padding()
    }
}
