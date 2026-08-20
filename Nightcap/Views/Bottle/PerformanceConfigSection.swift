//
//  PerformanceConfigSection.swift
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

struct PerformanceConfigSection: View {
    @ObservedObject var bottle: Bottle

    var body: some View {
        NCSection(title: "config.title.performance") {
            Picker("config.performancePreset", selection: $bottle.settings.performancePreset) {
                ForEach(PerformancePreset.allCases, id: \.self) { preset in
                    Text(preset.description()).tag(preset)
                }
            }

            // What the selected preset actually does. This used to be hidden
            // for `.balanced`, so the default — the preset most bottles are on
            // — was the one that explained nothing about itself.
            presetExplanation

            // The Shader Cache toggle stood here. It set
            // DXVK_SHADER_COMPILE_THREADS and __GL_SHADER_DISK_CACHE — the
            // first is not how the shipped DXVK is configured and the second
            // is an NVIDIA driver variable — so the switch did nothing on any
            // bottle. Removed with its environment writes.

            // Force D3D11 lived here as well as in Graphics, bound to the same
            // setting. It is a graphics-backend choice, so Graphics keeps it.
            NCToggleRow(
                title: "config.disableAppNap",
                isOn: $bottle.settings.disableAppNap,
                caption: "config.disableAppNap.info"
            )

            vcRedistRow
        }
    }

    // MARK: - Preset Explanation

    /// An icon-and-caption pair drawn by hand, with the preset's own glyph
    /// carrying the subject and the tint carrying nothing. `.unknown` keeps it
    /// quiet: describing the current choice is not a warning.
    private var presetExplanation: some View {
        NCNotice(
            status: .unknown,
            message: presetDescription(for: bottle.settings.performancePreset),
            symbol: presetIcon(for: bottle.settings.performancePreset)
        )
    }

    // MARK: - VC++ Runtime

    /// Either the fact that the runtime is present, or the notice that it is
    /// missing with the install alongside it. The missing case was a whole
    /// button dressed as a title-and-caption row, so nothing on screen said
    /// pressing it would run winetricks.
    @ViewBuilder
    private var vcRedistRow: some View {
        if bottle.settings.vcRedistInstalled {
            NCStatusBadge(status: .ready, label: "config.vcRedistInstalled")
        } else {
            NCNotice(
                status: .missing,
                message: String(localized: "config.installVcRedist.info"),
                title: "config.installVcRedist",
                symbol: "wrench.and.screwdriver"
            ) {
                Button("config.performance.vcRedist.install") {
                    Task {
                        await Winetricks.runCommand(command: "vcrun2019", bottle: bottle)
                        bottle.settings.vcRedistInstalled = true
                    }
                }
            }
        }
    }

    // MARK: - Performance Preset Helpers

    func presetIcon(for preset: PerformancePreset) -> String {
        switch preset {
        case .balanced:
            "scale.3d"
        case .performance:
            "bolt.fill"
        case .quality:
            "sparkles"
        case .unity:
            "cube.fill"
        }
    }

    func presetDescription(for preset: PerformancePreset) -> String {
        switch preset {
        case .balanced:
            String(localized: "config.preset.balanced.desc")
        case .performance:
            String(localized: "config.preset.performance.desc")
        case .quality:
            String(localized: "config.preset.quality.desc")
        case .unity:
            String(localized: "config.preset.unity.desc")
        }
    }
}
