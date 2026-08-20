//
//  GraphicsConfigSection.swift
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

import Metal
import NightcapKit
import SwiftUI

struct GraphicsConfigSection: View {
    @ObservedObject var bottle: Bottle
    /// Owned by ConfigView so Graphics and Display cannot disagree about it.
    let hasRunningProcesses: Bool
    /// Stops the bottle and refreshes the shared state, in that order.
    let stopBottle: () async -> Void

    private var resolvedBackend: GraphicsBackend {
        if bottle.settings.graphicsBackend == .recommended {
            return GraphicsBackendResolver.resolve()
        }
        return bottle.settings.graphicsBackend
    }

    var body: some View {
        NCSection(title: "config.title.graphics") {
            // Backend picker -- always visible
            BackendPickerView(
                selection: $bottle.settings.graphicsBackend,
                resolvedBackend: resolvedBackend,
                isBackendAvailable: { backend in
                    NightcapWineInstaller.isBackendAvailable(backend)
                }
            )

            // A bottle explicitly set to D3DMetal without its payload silently
            // degrades to WineD3D at launch — say so instead (issue #146).
            if bottle.settings.graphicsBackend == .d3dMetal,
               !NightcapWineInstaller.isBackendAvailable(.d3dMetal) {
                d3dMetalMissingNotice
            }

            if hasRunningProcesses {
                runningProcessNotice
            }

            // The single Force D3D11 control. Performance carried a second
            // Toggle bound to the same setting with the same label, on the same
            // page — moving each silently moved the other. Its caption came
            // with it; the backend controls belong here.
            NCToggleRow(
                title: "config.forceD3D11",
                isOn: $bottle.settings.forceD3D11,
                caption: "config.forceD3D11.info"
            )

            // Sequoia Compatibility Mode -- always visible
            NCToggleRow(
                title: "config.sequoiaCompat",
                isOn: $bottle.settings.sequoiaCompatMode,
                caption: sequoiaCompatCaption
            )

            if !programsWithGraphicsOverrides.isEmpty {
                programOverridesNotice
            }

            DXVKSettingsView(
                bottle: bottle,
                resolvedBackend: resolvedBackend,
                bottleURL: bottle.url
            )

            metalSettings

            if !programsWithGraphicsOverrides.isEmpty {
                programOverridesInfo
            }
        }
    }

    // MARK: - Notices

    /// Was a bare glyph-and-caption pair with no background, sitting a few
    /// points from a tinted banner that said something less serious. Nothing
    /// declared which of the two mattered more; this one is `.missing` because
    /// the payload is genuinely absent and the user has to change something.
    private var d3dMetalMissingNotice: some View {
        NCNotice(
            status: .missing,
            message: String(localized: "config.graphics.backend.d3dMetal.missingWarning")
        )
    }

    /// The bottle is live, which is the whole reason the setting will not take
    /// hold yet — so `.running`, and the one control that resolves it goes in
    /// the notice's action slot instead of being small red text inside the
    /// banner. `role: .destructive` says out loud what the red was hinting at.
    private var runningProcessNotice: some View {
        NCNotice(
            status: .running,
            message: String(localized: "config.graphics.nextLaunchInfo")
        ) {
            Button("config.graphics.stopBottle", role: .destructive) {
                Task { await stopBottle() }
            }
        }
    }

    /// Nothing is wrong and nothing is pending — some programs simply answer to
    /// their own setting — so this stays at `.unknown`'s quiet tint and keeps
    /// the sliders glyph that names the subject.
    private var programOverridesNotice: some View {
        NCNotice(
            status: .unknown,
            message: String(localized: "config.graphics.programOverridesActive"),
            symbol: "slider.horizontal.3"
        )
    }

    // MARK: - Captions

    /// On WineD3D the switch does nothing, and saying so is the caption's job.
    private var sequoiaCompatCaption: LocalizedStringKey {
        resolvedBackend == .wined3d
            ? "config.sequoiaCompat.d3dmetalOnly"
            : "config.sequoiaCompat.info"
    }
}

// MARK: - Metal

extension GraphicsConfigSection {
    /// A named group inside Graphics rather than a `.headline` that outranked
    /// the section header above it.
    private var metalSettings: some View {
        NCSubsection(title: "config.metal.title") {
            NCToggleRow(title: "config.metalHud", isOn: $bottle.settings.metalHud)

            NCToggleRow(
                title: "config.metalTrace",
                isOn: $bottle.settings.metalTrace,
                caption: "config.metalTrace.info"
            )

            if let device = MTLCreateSystemDefaultDevice(), device.supportsFamily(.apple9) {
                NCToggleRow(
                    title: "config.dxr",
                    isOn: $bottle.settings.dxrEnabled,
                    caption: "config.dxr.info"
                )
            }

            NCToggleRow(title: "config.metalValidation", isOn: $bottle.settings.metalValidation)
        }
    }
}

// MARK: - Per-Program Overrides

extension GraphicsConfigSection {
    private var programsWithGraphicsOverrides: [Program] {
        bottle.programs.filter { $0.settings.overrides?.graphicsBackend != nil }
    }

    private var programOverridesInfo: some View {
        NCSubsection(
            title: "config.graphics.programOverrides",
            systemImage: "slider.horizontal.3"
        ) {
            ForEach(programsWithGraphicsOverrides) { program in
                programOverrideRow(program)
            }
            Text("config.graphics.programOverrides.hint")
                .font(Theme.Typography.rowCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The program's name is a runtime `String`, so it is the row's title; the
    /// backend it was pinned to is a value the machine reads back, so it takes
    /// the monospaced treatment. The inherited fallback is prose and stays
    /// prose — though the list is filtered to programs that *have* an override,
    /// so that branch never renders today.
    private func programOverrideRow(_ program: Program) -> some View {
        let backend = program.settings.overrides?.graphicsBackend?.displayName
        return NCRow(title: program.name) {
            if let backend {
                Text(backend)
                    .font(Theme.Typography.machine)
                    .foregroundStyle(.secondary)
            } else {
                Text("config.graphics.inherited")
                    .font(Theme.Typography.rowCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
