//
//  SettingsView.swift
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

struct SettingsView: View {
    @AppStorage("killOnTerminate") var killOnTerminate = true
    @AppStorage("showMenuBarExtra") var showMenuBarExtra = false
    @AppStorage("checkNightcapWineUpdates") var checkNightcapWineUpdates = true
    @AppStorage("defaultBottleLocation") var defaultBottleLocation = BottleData.defaultBottleDir
    @AppStorage("preferredTerminal") var preferredTerminal = "terminal"

    var body: some View {
        Form {
            Section("settings.general") {
                Toggle("settings.toggle.kill.on.terminate", isOn: $killOnTerminate)
                Toggle("settings.toggle.menubar", isOn: $showMenuBarExtra)
                    .help("settings.toggle.menubar.help")
                Picker("settings.terminal", selection: $preferredTerminal) {
                    // installedTerminals should always include Terminal.app on macOS,
                    // but fall back to showing just Terminal if somehow empty
                    let terminals = TerminalApp.installedTerminals
                    ForEach(terminals.isEmpty ? [.terminal] : terminals) { terminal in
                        Text(terminal.displayName).tag(terminal.rawValue)
                    }
                }
                ActionView(
                    text: "settings.path",
                    subtitle: defaultBottleLocation.prettyPath(),
                    actionName: "create.browse"
                ) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.canCreateDirectories = true
                    panel.directoryURL = BottleData.containerDir
                    panel.begin { result in
                        if result == .OK, let url = panel.urls.first {
                            defaultBottleLocation = url
                        }
                    }
                }
            }
            Section("settings.updates") {
                Toggle("settings.toggle.nightcapwine.updates", isOn: $checkNightcapWineUpdates)
            }
            EngineSettingsSection()
            GPTKSettingsSection()
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: ViewWidth.medium)
    }
}

#Preview {
    SettingsView()
}
