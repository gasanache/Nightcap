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

/// Three tabs, because one column was the wrong shape.
///
/// This window is fixed-width and sized to its content, so its height was the
/// sum of every section on it — and the engine section alone ends in a
/// paragraph and a four-line checklist, which pushed the window past the point
/// where anything could be read at a glance. Each tab is now a bounded form
/// that scrolls, so a section growing no longer grows the window.
///
/// The split follows what the settings are about rather than what they were:
/// Wine holds the engine and the update check that keeps it current, and
/// Graphics holds the two halves of Direct3D 12 on Metal — the payload import
/// and the checklist saying which half is still missing — which were previously
/// on opposite ends of the window.
struct SettingsView: View {
    @AppStorage("killOnTerminate") var killOnTerminate = true
    @AppStorage("showMenuBarExtra") var showMenuBarExtra = false
    @AppStorage("checkNightcapWineUpdates") var checkNightcapWineUpdates = true
    @AppStorage("defaultBottleLocation") var defaultBottleLocation = BottleData.defaultBottleDir
    @AppStorage("preferredTerminal") var preferredTerminal = "terminal"
    @AppStorage(AppAppearance.storageKey) var appearance: AppAppearance = .system

    var body: some View {
        TabView {
            general
                .tabItem {
                    Label("settings.general", systemImage: "gearshape")
                }
            wine
                .tabItem {
                    Label("settings.tab.wine", systemImage: "wineglass")
                }
            graphics
                .tabItem {
                    Label("settings.tab.graphics", systemImage: "display")
                }
        }
        // One size for all three tabs: a Settings window that resizes itself as
        // you move between tabs is the other way this screen used to misbehave.
        .frame(width: ViewWidth.large, height: ViewHeight.medium)
    }

    /// The settings that are about Nightcap itself rather than about Wine.
    private var general: some View {
        Form {
            // No header: the tab is already called General, and a section
            // titled the same thing directly under it says it twice.
            Section {
                // Segmented rather than a menu: three fixed choices, all of
                // them short, and the current one worth seeing without opening
                // anything.
                Picker("settings.appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appearance) { _, newValue in
                    newValue.apply()
                }

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
                    chooseBottleLocation()
                }
            }
        }
        .formStyle(.grouped)
    }

    /// The runtime: which engine is installed, and whether the app watches for
    /// a newer one. The update toggle had a section of its own holding nothing
    /// else, three sections away from the engine it updates.
    private var wine: some View {
        Form {
            EngineSettingsSection()
            Section("settings.updates") {
                Toggle("settings.toggle.nightcapwine.updates", isOn: $checkNightcapWineUpdates)
            }
        }
        .formStyle(.grouped)
    }

    /// Both halves of Direct3D 12 on Metal: the payload you supply, and what is
    /// still outstanding before a bottle can select D3DMetal.
    private var graphics: some View {
        Form {
            GPTKSettingsSection()
            MetalRequirementsSection()
        }
        .formStyle(.grouped)
    }

    private func chooseBottleLocation() {
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

#Preview {
    SettingsView()
}
