//
//  InputConfigSection.swift
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

struct InputConfigSection: View {
    @ObservedObject var bottle: Bottle
    @StateObject private var controllerMonitor = ControllerMonitor()

    var body: some View {
        // A real Section. This was a bare VStack wearing a `.font(.headline)`
        // Label as a pretend header — which outranked the genuine section
        // headers around it — handed to a grouped Form that had no idea it was
        // meant to be a section at all.
        NCSection(
            title: "config.title.input",
            systemImage: "gamecontroller",
            accessory: {
                if bottle.settings.controllerCompatibilityMode {
                    // Domain-neutral: this is Input, and the badge used to
                    // borrow the launcher section's own "On".
                    NCStatusBadge(status: .ready, label: "status.on")
                }
            },
            content: { sectionContent }
        )
        .onAppear { controllerMonitor.startMonitoring() }
        .onDisappear { controllerMonitor.stopMonitoring() }
    }

    /// Every explanation in this section used to live in a `.help()` tooltip,
    /// so a user who did not hover learned nothing about what any of it did.
    /// They are captions now.
    ///
    /// The children go straight into the `Section`, as they do in Graphics and
    /// Performance. Wrapped in a `VStack` they were one Form row, so this was
    /// the only page section drawing no separators between its own settings.
    @ViewBuilder
    private var sectionContent: some View {
        NCToggleRow(
            title: "config.controllerCompat",
            isOn: $bottle.settings.controllerCompatibilityMode,
            caption: "config.controllerCompat.caption"
        )

        if bottle.settings.controllerCompatibilityMode {
            // Info notice about controller compatibility
            controllerCompatInfoBanner

            NCToggleRow(
                title: "config.disableHIDAPI",
                isOn: $bottle.settings.disableHIDAPI,
                caption: "config.disableHIDAPI.caption"
            )

            NCToggleRow(
                title: "config.allowBackgroundEvents",
                isOn: $bottle.settings.allowBackgroundEvents,
                caption: "config.allowBackgroundEvents.caption"
            )

            NCToggleRow(
                title: "config.disableControllerMapping",
                isOn: $bottle.settings.disableControllerMapping,
                caption: "config.disableControllerMapping.caption"
            )

            NCToggleRow(
                title: "config.useButtonLabels",
                isOn: $bottle.settings.useButtonLabels,
                caption: "config.useButtonLabels.caption"
            )

            // The onChange writes Wine registry keys, so it has to survive
            // the conversion intact.
            NCToggleRow(
                title: "input.commandActsAsControl.title",
                isOn: $bottle.settings.commandActsAsControl,
                caption: "input.commandActsAsControl.caption"
            )
            .onChange(of: bottle.settings.commandActsAsControl) { _, newValue in
                applyCommandKeyMapping(enabled: newValue)
            }
            .accessibilityIdentifier("input.commandActsAsControl")

            connectedControllersPanel

            NCNotice(status: .unknown, message: String(localized: "input.stillNotWorking"))
        }
    }

    // MARK: - Info banner

    /// Nothing is wrong and nothing is pending — this only says what the
    /// switches below it do — so it is the quiet status with an info glyph,
    /// rather than the hand-drawn blue rectangle that made the mildest note in
    /// the section the loudest thing in it.
    private var controllerCompatInfoBanner: some View {
        NCNotice(
            status: .unknown,
            message: String(localized: "input.workarounds.message"),
            title: "input.workarounds.title",
            symbol: "info.circle"
        )
    }

    // MARK: - Connected Controllers Panel

    private var connectedControllersPanel: some View {
        // Always visible.
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Label("input.controllers.title", systemImage: "gamecontroller.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !controllerMonitor.controllers.isEmpty {
                    Text("\(controllerMonitor.controllers.count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                if controllerMonitor.controllers.isEmpty {
                    emptyControllerState
                } else {
                    controllerList
                    bluetoothWarningBanner
                }

                controllerActionButtons

                // Last refreshed timestamp
                (Text("input.controllers.lastRefreshed")
                    + Text(" ")
                    + Text(controllerMonitor.lastRefreshed, style: .relative))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyControllerState: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "gamecontroller")
                    .foregroundStyle(.secondary)
                Text("input.controllers.none")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("input.controllers.none.hint")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Controller List

    private var controllerList: some View {
        ForEach(controllerMonitor.controllers) { controller in
            controllerRow(controller)
        }
    }

    private func controllerRow(_ controller: ControllerInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Controller name
            Text(controller.name)
                .font(.callout)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                // Type badge
                HStack(spacing: 4) {
                    Image(systemName: controller.typeBadge.sfSymbol)
                        .font(.caption)
                    Text(controller.typeBadge.displayName)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                // Connection badge
                HStack(spacing: 4) {
                    Image(systemName: controller.connectionType.sfSymbol)
                        .font(.caption)
                    Text(controller.connectionType.rawValue)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                // Battery level
                if let level = controller.batteryLevel {
                    HStack(spacing: 4) {
                        Image(systemName: batterySymbol(level: level, state: controller.batteryState))
                            .font(.caption)
                        Text("input.controllers.battery \(Int(level * 100))")
                            .font(.caption)
                        if controller.batteryState == "charging" {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Bluetooth Warning Banner

    /// A caution the user can act on — plug the pad in — so it takes the same
    /// orange status and warning glyph as every other "you may want to change
    /// something" notice, instead of a third hand-tinted rectangle.
    @ViewBuilder
    private var bluetoothWarningBanner: some View {
        let hasBluetoothController = controllerMonitor.controllers.contains {
            $0.connectionType == .bluetooth
        }

        if hasBluetoothController {
            NCNotice(
                status: .missing,
                message: String(localized: "input.bluetoothWarning"),
                symbol: "exclamationmark.triangle.fill"
            )
        }
    }

    // MARK: - Action Buttons

    private var controllerActionButtons: some View {
        HStack(spacing: 12) {
            Button {
                controllerMonitor.refresh()
            } label: {
                Label("button.refresh", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Button {
                copyControllerInfo()
            } label: {
                Label("input.controllers.copyInfo", systemImage: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .disabled(controllerMonitor.controllers.isEmpty)

            Spacer()

            // Test Input hint
            Text("input.controllers.testHint")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private func batterySymbol(level: Float, state: String?) -> String {
        if state == "charging" {
            return "battery.100.bolt"
        }
        switch level {
        case 0.75...:
            return "battery.100"
        case 0.50 ..< 0.75:
            return "battery.75"
        case 0.25 ..< 0.50:
            return "battery.50"
        default:
            return "battery.25"
        }
    }

    private func copyControllerInfo() {
        var lines = ["Connected Controllers:"]
        for controller in controllerMonitor.controllers {
            lines.append("  - \(controller.name)")
            lines.append("    Type: \(controller.typeBadge.displayName)")
            lines.append("    Connection: \(controller.connectionType.rawValue)")
            if let level = controller.batteryLevel {
                let stateStr = controller.batteryState.map { " (\($0))" } ?? ""
                lines.append("    Battery: \(Int(level * 100))%\(stateStr)")
            }
            lines.append("    Product Category: \(controller.productCategory)")
        }
        lines.append("")
        lines.append("History:")
        for entry in controllerMonitor.recentHistory {
            lines.append(
                "  - \(entry.name) (\(entry.connectionType)) last seen: "
                    + "\(entry.lastSeen.formatted(.dateTime.month().day().hour().minute()))"
            )
        }

        let text = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Writes (or removes) the Wine Mac driver registry keys that map macOS
    /// Command to Windows Ctrl. Runs `wine reg` so the UI stays responsive.
    @MainActor
    private func applyCommandKeyMapping(enabled: Bool) {
        let bottleRef = bottle
        let value = enabled ? "Y" : "N"
        Task {
            let key = #"HKCU\Software\Wine\Mac Driver"#
            for name in ["LeftCommandIsCtrl", "RightCommandIsCtrl"] {
                _ = try? await Wine.runWine(
                    ["reg", "add", key, "/v", name, "/t", "REG_SZ", "/d", value, "/f"],
                    bottle: bottleRef
                )
            }
        }
    }
}
