//
//  DXVKSettingsView.swift
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
import NightcapKit
import SwiftUI

struct DXVKSettingsView: View {
    @ObservedObject var bottle: Bottle
    let resolvedBackend: GraphicsBackend
    let bottleURL: URL

    @State private var confExists: Bool = false

    private var isDXVKActive: Bool {
        resolvedBackend == .dxvk
    }

    private var confURL: URL {
        bottleURL.appending(path: "dxvk.conf")
    }

    var body: some View {
        // A named group inside the Graphics section, not a heading that
        // outranks it. The title was a `.headline`, one step *larger* than the
        // section header above it, so the nesting read upside down.
        NCSubsection(title: "config.dxvk.title") {
            // The grey capsule said "not currently active" in the app's own
            // private dialect of status. `.unknown` is the honest reading: DXVK
            // is not the resolved backend, so nothing here is in force — and
            // that is not a failure or something the user withheld.
            if !isDXVKActive {
                NCStatusBadge(status: .unknown, label: "config.dxvk.inactive")
            }

            NCToggleRow(
                title: "config.dxvk.async",
                isOn: $bottle.settings.dxvkAsync,
                caption: "config.dxvk.async.info"
            )
            .disabled(!isDXVKActive)

            // DXVK HUD preset picker
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Picker("config.dxvkHud", selection: $bottle.settings.dxvkHud) {
                    Text("config.dxvkHud.off").tag(DXVKHUD.off)
                    Text("config.dxvkHud.fps").tag(DXVKHUD.fps)
                    Text("config.dxvkHud.partial").tag(DXVKHUD.partial)
                    Text("config.dxvkHud.full").tag(DXVKHUD.full)
                }
                Text("config.dxvkHud.info")
                    .font(Theme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(!isDXVKActive)

            // dxvk.conf management
            dxvkConfManagement
        }
    }

    // MARK: - dxvk.conf Management

    private var dxvkConfManagement: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            Divider()
            // The row's subject is a filename, so it takes the monospaced
            // title slot rather than being set in prose. The right-hand side
            // used to repeat the same filename back — `confURL` is always
            // `dxvk.conf` — so only the "not found" half of that pair carried
            // anything, and it is the caption now.
            NCRow(
                title: String(localized: "config.dxvk.confFile"),
                caption: confExists ? nil : String(localized: "config.dxvk.confNotFound"),
                isMachineTitle: true
            ) {
                EmptyView()
            }
            HStack(spacing: Theme.Space.snug) {
                Button("config.dxvk.openInEditor") {
                    if !confExists {
                        createDefaultConf()
                    }
                    NSWorkspace.shared.open(confURL)
                }
                Button("config.dxvk.revealInFinder") {
                    NSWorkspace.shared.activateFileViewerSelecting([confURL])
                }
                .disabled(!confExists)
                Button("config.dxvk.reset", role: .destructive) {
                    try? FileManager.default.removeItem(at: confURL)
                    confExists = false
                }
                .disabled(!confExists)
            }
            .font(Theme.Typography.rowCaption)
        }
        .disabled(!isDXVKActive)
        .onAppear {
            confExists = FileManager.default.fileExists(atPath: confURL.path(percentEncoded: false))
        }
    }

    // MARK: - Default Config Creation

    private func createDefaultConf() {
        let defaultContent = """
        # DXVK Configuration
        # See: https://github.com/doitsujin/dxvk/blob/master/dxvk.conf
        #
        # Uncomment and modify settings as needed.
        # dxgi.maxFrameLatency = 1
        # d3d11.maxFeatureLevel = 11_1
        """
        try? defaultContent.write(to: confURL, atomically: true, encoding: .utf8)
        confExists = true
    }
}
