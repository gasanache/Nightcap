//
//  PinView.swift
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

struct PinView: View {
    @Environment(NCToastCenter.self) private var toastCentre

    @ObservedObject var bottle: Bottle
    @ObservedObject var program: Program
    @State var pin: PinnedProgram
    @Binding var path: NavigationPath

    /// The icon arrives from ``IconCache`` as an `NSImage`, and ``NCTile``
    /// takes it in that form — the intermediate `Image` only existed because
    /// this view drew the tile itself.
    @State private var icon: NSImage?
    @State private var showRenameSheet = false
    @State private var name: String = ""
    @State private var opening: Bool = false

    var body: some View {
        // The tile geometry — the square, the icon derived from it, the button
        // that makes launching reachable by keyboard — is ``NCTile``. This view
        // had its own copy of those numbers, and ``PinAddView`` had a third,
        // which is how the two tiles drifted apart in the first place.
        NCTile(
            title: name,
            systemImage: "app.dashed",
            nsImage: icon,
            isOpening: opening,
            accessibilityID: "pin.launch",
            requiresDoubleClick: true,
            action: runProgram
        )
        .help("pin.launch.help")
        .contextMenu {
            ProgramMenuView(program: program, path: $path)

            Button("button.rename", systemImage: "pencil.line") {
                showRenameSheet.toggle()
            }
            .labelStyle(.titleAndIcon)
            Button("button.showInFinder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([program.url])
            }
            .labelStyle(.titleAndIcon)
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameView("rename.pin.title", name: name) { newName in
                name = newName
            }
        }
        .task {
            name = pin.name
            icon = await IconCache.shared.iconOrFallback(for: program.url, peFile: program.peFile)
        }
        .onChange(of: name) {
            if let index = bottle.settings.pins.firstIndex(where: {
                let exists = FileManager.default.fileExists(atPath: pin.url?.path(percentEncoded: false) ?? "")
                return $0.url == pin.url && exists
            }) {
                bottle.settings.pins[index].name = name
            }
        }
    }

    func runProgram() {
        withAnimation(.easeIn(duration: 0.25)) {
            opening = true
        } completion: {
            withAnimation(.easeOut(duration: 0.1)) {
                opening = false
            }
        }

        // Capture modifier flags synchronously before entering async context
        let useTerminal = NSEvent.modifierFlags.contains(.shift)
        Task {
            let result = await program.launchWithUserMode(useTerminal: useTerminal)
            withAnimation {
                result.announce(on: toastCentre)
            }
        }
    }
}
