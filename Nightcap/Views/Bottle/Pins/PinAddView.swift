//
//  PinAddView.swift
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

import NightcapKit
import SwiftUI

struct PinAddView: View {
    let bottle: Bottle
    @State private var showingSheet = false

    var body: some View {
        // The same ``NCTile`` the pins themselves are, so the add tile lines up
        // with them in ``BottleView``'s grid instead of mirroring their
        // geometry by hand. `String(localized:)` because the tile's title is a
        // runtime `String` — a `LocalizedStringKey` would look up the label
        // text as a key and quietly render the fallback.
        NCTile(
            title: String(localized: "pin.help"),
            systemImage: "plus.circle",
            action: { showingSheet = true }
        )
        .sheet(isPresented: $showingSheet) {
            PinCreationView(bottle: bottle)
        }
    }
}

#Preview {
    PinAddView(bottle: Bottle(bottleUrl: URL(filePath: "")))
}
