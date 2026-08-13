//
//  CleanupConfigSection.swift
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

struct CleanupConfigSection: View {
    @ObservedObject var bottle: Bottle

    var body: some View {
        Section("config.cleanup") {
            Picker("config.cleanup.clipboardPolicy", selection: $bottle.settings.clipboardPolicy) {
                Text("config.cleanup.clipboardPolicy.auto").tag(ClipboardPolicy.auto)
                Text("config.cleanup.clipboardPolicy.warn").tag(ClipboardPolicy.alwaysWarn)
                Text("config.cleanup.clipboardPolicy.clear").tag(ClipboardPolicy.alwaysClear)
                Text("config.cleanup.clipboardPolicy.never").tag(ClipboardPolicy.never)
            }
            .help("config.cleanup.clipboardPolicy.help")

            Picker("config.cleanup.killOnQuit", selection: $bottle.settings.killOnQuit) {
                Text("config.cleanup.killOnQuit.inherit").tag(KillOnQuitPolicy.inherit)
                Text("config.cleanup.killOnQuit.always").tag(KillOnQuitPolicy.alwaysKill)
                Text("config.cleanup.killOnQuit.never").tag(KillOnQuitPolicy.neverKill)
            }
            .help("config.cleanup.killOnQuit.help")
        }
    }
}
