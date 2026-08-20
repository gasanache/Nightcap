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

/// Two settings that reach outside the bottle — one touches the Mac clipboard,
/// the other decides what happens to running programs when Nightcap quits.
///
/// Both used to keep their entire explanation in a `.help()` tooltip, so a user
/// who never hovered was never told that "Always Clear" empties their own
/// clipboard on every launch. The explanations are captions now, drawn on
/// screen, which is the only version of them this section offers.
struct CleanupConfigSection: View {
    @ObservedObject var bottle: Bottle

    var body: some View {
        NCSection(title: "config.cleanup", systemImage: "sparkles") {
            clipboardPolicyRow
            killOnQuitRow
        }
    }

    private var clipboardPolicyRow: some View {
        NCRow(
            title: String(localized: "config.cleanup.clipboardPolicy"),
            caption: String(localized: "config.cleanup.clipboardPolicy.caption")
        ) {
            Picker("config.cleanup.clipboardPolicy", selection: $bottle.settings.clipboardPolicy) {
                Text("config.cleanup.clipboardPolicy.auto").tag(ClipboardPolicy.auto)
                Text("config.cleanup.clipboardPolicy.warn").tag(ClipboardPolicy.alwaysWarn)
                Text("config.cleanup.clipboardPolicy.clear").tag(ClipboardPolicy.alwaysClear)
                Text("config.cleanup.clipboardPolicy.never").tag(ClipboardPolicy.never)
            }
            .labelsHidden()
        }
    }

    private var killOnQuitRow: some View {
        NCRow(
            title: String(localized: "config.cleanup.killOnQuit"),
            caption: String(localized: "config.cleanup.killOnQuit.caption")
        ) {
            Picker("config.cleanup.killOnQuit", selection: $bottle.settings.killOnQuit) {
                Text("config.cleanup.killOnQuit.inherit").tag(KillOnQuitPolicy.inherit)
                Text("config.cleanup.killOnQuit.always").tag(KillOnQuitPolicy.alwaysKill)
                Text("config.cleanup.killOnQuit.never").tag(KillOnQuitPolicy.neverKill)
            }
            .labelsHidden()
        }
    }
}
