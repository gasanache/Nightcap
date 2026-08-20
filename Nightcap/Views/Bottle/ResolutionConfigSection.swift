//
//  ResolutionConfigSection.swift
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

struct ResolutionConfigSection: View {
    @ObservedObject var bottle: Bottle
    /// Owned by ConfigView; see GraphicsConfigSection.
    let hasRunningProcesses: Bool
    @State private var widthText: String = ""
    @State private var heightText: String = ""

    /// Wide enough for five digits and no wider, so the two fields and the ×
    /// between them read as one measurement.
    private static let dimensionFieldWidth: CGFloat = 80

    var body: some View {
        NCSection(title: "config.title.display", systemImage: "display") {
            NCToggleRow(
                title: "config.virtualDesktop",
                isOn: $bottle.settings.virtualDesktopEnabled,
                caption: "config.virtualDesktop.info"
            )
            .onChange(of: bottle.settings.virtualDesktopEnabled) { _, enabled in
                persistVirtualDesktop(enabled: enabled)
            }

            if bottle.settings.virtualDesktopEnabled {
                resolutionPicker

                if bottle.settings.resolutionPreset == .matchDisplay {
                    matchDisplayNotice
                }

                if bottle.settings.resolutionPreset == .custom {
                    customResolutionFields
                }

                nextLaunchNotice
            }

            if hasRunningProcesses {
                runningProcessNotice
            }
        }
        .animation(.default, value: bottle.settings.virtualDesktopEnabled)
        .task {
            await loadRegistryState()
            syncCustomFields()
        }
    }

    // MARK: - Resolution Picker

    private var resolutionPicker: some View {
        Picker("config.virtualDesktop.resolution", selection: $bottle.settings.resolutionPreset) {
            ForEach(ResolutionPreset.allCases, id: \.self) { preset in
                Text(presetLabel(preset)).tag(preset)
            }
        }
        .onChange(of: bottle.settings.resolutionPreset) { _, _ in
            syncCustomFields()
            persistResolution()
        }
    }

    // MARK: - Custom Resolution Fields

    private var customResolutionFields: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("config.virtualDesktop.width")
                    .font(Theme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
                TextField("1920", text: $widthText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: Self.dimensionFieldWidth)
                    .onChange(of: widthText) { _, newValue in
                        if let val = Int(newValue) {
                            bottle.settings.customResolutionWidth = min(max(val, 640), 7_680)
                        }
                    }
                    .onSubmit {
                        validateAndPersistCustom()
                    }
            }
            // A multiplication sign, not a word, so it is set verbatim rather
            // than looked up in the string table.
            Text(verbatim: "\u{00D7}")
                .foregroundStyle(.secondary)
                .padding(.top, Theme.Space.row)
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                Text("config.virtualDesktop.height")
                    .font(Theme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
                TextField("1080", text: $heightText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: Self.dimensionFieldWidth)
                    .onChange(of: heightText) { _, newValue in
                        if let val = Int(newValue) {
                            bottle.settings.customResolutionHeight = min(max(val, 480), 4_320)
                        }
                    }
                    .onSubmit {
                        validateAndPersistCustom()
                    }
            }
        }
    }

    // MARK: - Helpers

    func presetLabel(_ preset: ResolutionPreset) -> String {
        switch preset {
        case .matchDisplay:
            String(localized: "config.virtualDesktop.matchDisplay.label")
        case .custom:
            String(localized: "config.virtualDesktop.custom")
        default:
            preset.label
        }
    }

    func syncCustomFields() {
        widthText = "\(bottle.settings.customResolutionWidth)"
        heightText = "\(bottle.settings.customResolutionHeight)"
    }
}

// MARK: - Notices

/// This section used to say three things in three different shapes: a bare
/// icon-and-caption pair, a caption on its own, and a tinted rounded rectangle.
/// They are all notices now, and each declares how serious it is rather than
/// leaving that to whichever colour was reached for at the time.
extension ResolutionConfigSection {
    /// What "Match Display" resolves to, so the choice is not taken on trust.
    @ViewBuilder
    private var matchDisplayNotice: some View {
        if let screen = NSScreen.main {
            let pixelWidth = Int(screen.frame.width * screen.backingScaleFactor)
            let pixelHeight = Int(screen.frame.height * screen.backingScaleFactor)
            NCNotice(
                status: .unknown,
                message: String(
                    format: String(localized: "config.virtualDesktop.matchDisplay.notice"),
                    "\(pixelWidth)\u{00D7}\(pixelHeight)"
                ),
                symbol: "display"
            )
        } else {
            // The app asked the display how big it is and did not get an
            // answer, which is a failed read rather than a note.
            NCNotice(
                status: .failed,
                message: String(localized: "config.virtualDesktop.matchDisplay.fallback")
            )
        }
    }

    /// Nothing is wrong, but nothing has happened yet either.
    private var nextLaunchNotice: some View {
        NCNotice(
            status: .unknown,
            message: String(localized: "config.virtualDesktop.nextLaunch")
        )
    }

    /// Something in this bottle is live, which is exactly why the resolution
    /// cannot change underneath it.
    private var runningProcessNotice: some View {
        NCNotice(
            status: .running,
            message: String(localized: "config.virtualDesktop.processesRunning")
        )
    }
}

// MARK: - Registry Persistence

extension ResolutionConfigSection {
    func persistVirtualDesktop(enabled: Bool) {
        Task {
            do {
                if enabled {
                    let res = effectiveResolutionString()
                    try await Wine.enableVirtualDesktop(bottle: bottle, resolution: res)
                } else {
                    try await Wine.disableVirtualDesktop(bottle: bottle)
                }
            } catch {
                bottle.settings.virtualDesktopEnabled = !enabled
            }
        }
    }

    func persistResolution() {
        guard bottle.settings.virtualDesktopEnabled else { return }
        Task {
            do {
                let res = effectiveResolutionString()
                try await Wine.enableVirtualDesktop(bottle: bottle, resolution: res)
            } catch {
                // Best effort; user will see "next launch" notice
            }
        }
    }

    func validateAndPersistCustom() {
        let width = min(max(Int(widthText) ?? 1_920, 640), 7_680)
        let height = min(max(Int(heightText) ?? 1_080, 480), 4_320)
        bottle.settings.customResolutionWidth = width
        bottle.settings.customResolutionHeight = height
        widthText = "\(width)"
        heightText = "\(height)"
        persistResolution()
    }

    func effectiveResolutionString() -> String {
        let preset = bottle.settings.resolutionPreset
        switch preset {
        case .matchDisplay:
            if let screen = NSScreen.main {
                let width = Int(screen.frame.width * screen.backingScaleFactor)
                let height = Int(screen.frame.height * screen.backingScaleFactor)
                return "\(width)x\(height)"
            }
            return "1920x1080"
        case .custom:
            return "\(bottle.settings.customResolutionWidth)x\(bottle.settings.customResolutionHeight)"
        default:
            if let dims = preset.dimensions {
                return "\(dims.width)x\(dims.height)"
            }
            return "1920x1080"
        }
    }

    func loadRegistryState() async {
        do {
            if let resolution = try await Wine.queryVirtualDesktop(bottle: bottle) {
                bottle.settings.virtualDesktopEnabled = true
                let parts = resolution.split(separator: "x")
                if parts.count == 2, let width = Int(parts[0]), let height = Int(parts[1]) {
                    matchRegistryToPreset(width: width, height: height)
                }
            } else {
                bottle.settings.virtualDesktopEnabled = false
            }
        } catch {
            // Registry query failed; leave defaults
        }
    }

    func matchRegistryToPreset(width: Int, height: Int) {
        for preset in ResolutionPreset.allCases {
            if let dims = preset.dimensions, dims.width == width, dims.height == height {
                bottle.settings.resolutionPreset = preset
                return
            }
        }
        bottle.settings.resolutionPreset = .custom
        bottle.settings.customResolutionWidth = width
        bottle.settings.customResolutionHeight = height
    }
}
