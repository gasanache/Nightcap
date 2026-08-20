//
//  WineConfigSection.swift
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
import os
import SwiftUI

enum RetinaModeState: Equatable {
    case enabled, disabled, unknown
}

struct WineConfigSection: View {
    private static let logger = Logger(subsystem: Bundle.nightcapBundleIdentifier, category: "ConfigView")
    @ObservedObject var bottle: Bottle
    @Binding var buildVersion: String
    @Binding var retinaModeState: RetinaModeState
    @Binding var dpiConfig: Int
    @Binding var winVersionLoadingState: LoadingState
    @Binding var buildVersionLoadingState: LoadingState
    @Binding var retinaModeLoadingState: LoadingState
    @Binding var dpiConfigLoadingState: LoadingState
    @Binding var dpiSheetPresented: Bool
    var onRetryBuildVersion: (() -> Void)?
    var onRetryRetinaMode: (() -> Void)?
    var onRetryDpi: (() -> Void)?

    var body: some View {
        NCSection(title: "config.title.wine", systemImage: "wineglass") {
            windowsVersionRow
            buildVersionRow
            retinaModeRow
            enhancedSyncRow
            dpiRow
            avxRow
        }
    }
}

// MARK: - Rows

extension WineConfigSection {
    private var windowsVersionRow: some View {
        SettingItemView(
            title: "config.winVersion",
            description: "config.winVersion.info",
            loadingState: winVersionLoadingState
        ) {
            Picker("config.winVersion", selection: $bottle.settings.windowsVersion) {
                ForEach(WinVersion.allCases.reversed(), id: \.self) {
                    Text($0.pretty())
                }
            }
        }
    }

    private var buildVersionRow: some View {
        SettingItemView(
            title: "config.buildVersion",
            description: "config.buildVersion.info",
            loadingState: buildVersionLoadingState,
            onRetry: onRetryBuildVersion
        ) {
            TextField(
                "config.buildVersion.notSet",
                text: $buildVersion
            )
            .multilineTextAlignment(.trailing)
            .textFieldStyle(PlainTextFieldStyle())
            .onSubmit {
                submitBuildVersion()
            }
        }
    }

    /// The hint about the unknown state used to be squeezed into the picker's
    /// own column at the right-hand edge of the row. It says the same thing
    /// under the same condition, in the shape the rest of the app uses for a
    /// note.
    @ViewBuilder
    private var retinaModeRow: some View {
        SettingItemView(
            title: "config.retinaMode",
            description: "config.retinaMode.info",
            loadingState: retinaModeLoadingState,
            onRetry: onRetryRetinaMode
        ) {
            Picker("config.retinaMode", selection: $retinaModeState) {
                Text("config.retinaMode.on").tag(RetinaModeState.enabled)
                Text("config.retinaMode.off").tag(RetinaModeState.disabled)
                // Only offered while the state genuinely is unknown.
                // `applyRetinaMode` ignores a switch *to* unknown, so as a
                // permanent segment it let the control show a state the prefix
                // no longer had.
                if retinaModeState == .unknown {
                    Text("config.retinaMode.unknown").tag(RetinaModeState.unknown)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: retinaModeState) { oldValue, newValue in
                applyRetinaMode(from: oldValue, to: newValue)
            }
        }

        if retinaModeLoadingState == .success, retinaModeState == .unknown {
            NCNotice(
                status: .unknown,
                message: String(localized: "config.retinaMode.unknownHint")
            )
        }
    }

    /// Nothing here is read off the prefix — the value lives in the bottle's own
    /// settings — so this row is never anything but ready. It is in the wrapper
    /// anyway so that its explanation sits where every other explanation in the
    /// section sits.
    private var enhancedSyncRow: some View {
        SettingItemView(
            title: "config.enhancedSync",
            description: "config.enhancedSync.info",
            loadingState: .success
        ) {
            Picker("config.enhancedSync", selection: $bottle.settings.enhancedSync) {
                Text("config.enhancedSync.none").tag(EnhancedSync.none)
                Text("config.enhancedSync.esync").tag(EnhancedSync.esync)
                Text("config.enhancedSync.msync").tag(EnhancedSync.msync)
            }
        }
    }

    private var dpiRow: some View {
        SettingItemView(
            title: "config.dpi",
            description: "config.dpi.info",
            loadingState: dpiConfigLoadingState,
            onRetry: onRetryDpi
        ) {
            Button("config.inspect") {
                dpiSheetPresented = true
            }
            .sheet(isPresented: $dpiSheetPresented) {
                DPIConfigSheetView(
                    dpiConfig: $dpiConfig,
                    isRetinaMode: Binding(
                        get: { retinaModeState == .enabled },
                        set: { _ in }
                    ),
                    presented: $dpiSheetPresented
                )
            }
        }
    }

    /// The warning used to be drawn inside the `Toggle`'s own label, at a font
    /// weight used nowhere else in the app, so a caution about performance was
    /// wearing the same clothes as the name of the setting. It is a notice under
    /// the row now, and it still appears only while AVX is advertised.
    @ViewBuilder
    private var avxRow: some View {
        SettingItemView(
            title: "config.avx",
            description: "config.avx.info",
            loadingState: .success
        ) {
            Toggle("config.avx", isOn: $bottle.settings.avxEnabled)
        }

        if bottle.settings.avxEnabled {
            NCNotice(
                status: .missing,
                message: String(localized: "config.avx.warning"),
                symbol: "exclamationmark.triangle.fill"
            )
        }
    }
}

// MARK: - Actions

extension WineConfigSection {
    /// Unchanged from when it was written inline on the text field: parse, and
    /// only write to the prefix if the field holds a number.
    @MainActor
    private func submitBuildVersion() {
        guard let version = Int(buildVersion) else { return }
        buildVersionLoadingState = .modifying
        Task(priority: .userInitiated) {
            do {
                try await Wine.changeBuildVersion(bottle: bottle, version: version)
                buildVersionLoadingState = .success
            } catch {
                Self.logger.error(
                    "Failed to change build version: \(error.localizedDescription)"
                )
                buildVersionLoadingState = .failed
            }
        }
    }

    @MainActor
    private func applyRetinaMode(from oldValue: RetinaModeState, to newValue: RetinaModeState) {
        guard newValue != .unknown, newValue != oldValue else { return }
        let boolValue = newValue == .enabled
        Task(priority: .userInitiated) {
            retinaModeLoadingState = .modifying
            do {
                try await Wine.changeRetinaMode(
                    bottle: bottle, retinaMode: boolValue
                )
                retinaModeLoadingState = .success
            } catch {
                Self.logger.error(
                    "Failed to change retina mode: \(error.localizedDescription)"
                )
                retinaModeLoadingState = .failed
            }
        }
    }
}
