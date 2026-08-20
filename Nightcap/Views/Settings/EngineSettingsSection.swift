//
//  EngineSettingsSection.swift
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
import SemanticVersion
import SwiftUI

/// Asks the app to install a particular Wine engine, carrying its version.
extension Notification.Name {
    static let installEngineRequested = Notification.Name("installEngineRequested")

    /// Posted once setup closes, so anything showing runtime state reloads.
    /// Without it the engine list and the GPTK section keep reporting whatever
    /// was installed when they first appeared, and only a reopen corrects them.
    static let runtimeChanged = Notification.Name("runtimeChanged")
}

/// Lets the user choose which Wine engine is installed.
///
/// There are two and they are a trade rather than a progression: the default is
/// newer Wine, and the GPTK-capable build is older Wine that can execute
/// Apple's D3DMetal. Before this, taking the second one meant installing a
/// runtime by hand, because the manifest only ever named the first.
struct EngineSettingsSection: View {
    @Environment(\.openWindow) private var openWindow

    @State private var engines: [NightcapWineVersion] = []
    @State private var installed: NightcapWineVersion?
    @State private var loadFailure: String?
    @State private var isLoading: Bool = true

    var body: some View {
        Section {
            if isLoading {
                HStack(spacing: Theme.Space.snug) {
                    ProgressView().controlSize(.small)
                    Text("settings.engine.checking")
                        .foregroundStyle(.secondary)
                }
            } else if let loadFailure {
                // `.unknown` rather than `.failed`: being offline is the common
                // way to land here, it is not the user's doing, and a red banner
                // would say the engine list is broken when it is only unread.
                NCNotice(status: .unknown, message: loadFailure)
            } else {
                // Keyed on the archive, not the tag: every engine now ships
                // from the same release, so the tag stopped being unique and
                // SwiftUI rendered the first engine once per entry.
                ForEach(engines, id: \.downloadURL) { engine in
                    row(for: engine)
                }
            }
        } header: {
            Text("settings.engine")
        } footer: {
            Text("settings.engine.footer")
                .font(Theme.Typography.rowCaption)
                .foregroundStyle(.secondary)
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .runtimeChanged)) { _ in
            Task { await load() }
        }
    }

    private func row(for engine: NightcapWineVersion) -> some View {
        let isCurrent = installed?.version == engine.version
        let isGPTK = engine.gptkCapable == true
        let title: String.LocalizationValue = isGPTK
            ? "settings.engine.gptk"
            : "settings.engine.standard"
        let caption: String.LocalizationValue = isGPTK
            ? "settings.engine.gptk.caption"
            : "settings.engine.standard.caption"
        return NCRow(
            title: String(localized: title),
            caption: String(localized: caption),
            machine: versionStamp(of: engine)
        ) {
            if isCurrent {
                NCStatusBadge(status: .ready, label: "settings.engine.installed")
            } else {
                NCStatusBadge(status: .available, label: "settings.engine.available")
                Button("settings.engine.install") {
                    // The observer lives on the main window's content view. In
                    // menu-bar-only mode that window may not exist, so the post
                    // went into the void; open it first and give it a beat to
                    // mount before posting.
                    openWindow(id: NightcapApp.mainWindowID)
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        NotificationCenter.default.post(
                            name: .installEngineRequested,
                            object: engine.version
                        )
                    }
                }
                .controlSize(.small)
            }
        }
    }

    /// The version numbers alone, for the row's machine slot.
    ///
    /// The number is the runtime package's, not Wine's — runtime 3.1.1 carries
    /// Wine 11 — so it is labelled as such rather than reading as a Wine
    /// version that would be years out of date. What the engine trades away is
    /// prose and stays in the caption; welding the two together with a middle
    /// dot made a sentence that was half stamp and half explanation.
    private func versionStamp(of engine: NightcapWineVersion) -> String {
        let version = engine.version
        var parts = [String(
            format: String(localized: "settings.engine.runtime %@"),
            "\(version.major).\(version.minor).\(version.patch)"
        )]
        if let dxmt = engine.dxmtVersion {
            parts.append(String(format: String(localized: "settings.engine.dxmt %@"), dxmt))
        }
        return parts.joined(separator: " · ")
    }

    private func load() async {
        defer { isLoading = false }
        installed = NightcapWineInstaller.nightcapWineInfo()

        guard let url = URL(string: DistributionConfig.versionPlistURL) else {
            loadFailure = String(localized: "settings.engine.error.address")
            return
        }
        do {
            let (data, _) = try await URLSession(configuration: .ephemeral).data(from: url)
            let manifest = try PropertyListDecoder().decode(NightcapWineVersion.self, from: data)
            engines = manifest.availableEngines
        } catch {
            // Offline is the common case here and not worth an alert; the
            // section simply says nothing is known rather than looking broken.
            loadFailure = String(
                format: String(localized: "settings.engine.error.unreachable %@"),
                error.localizedDescription
            )
        }
    }
}
