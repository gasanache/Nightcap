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
}

/// Lets the user choose which Wine engine is installed.
///
/// There are two and they are a trade rather than a progression: the default is
/// newer Wine, and the GPTK-capable build is older Wine that can execute
/// Apple's D3DMetal. Before this, taking the second one meant installing a
/// runtime by hand, because the manifest only ever named the first.
struct EngineSettingsSection: View {
    @State private var engines: [NightcapWineVersion] = []
    @State private var installed: NightcapWineVersion?
    @State private var loadFailure: String?
    @State private var isLoading: Bool = true

    var body: some View {
        Section {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Checking available engines\u{2026}")
                        .foregroundStyle(.secondary)
                }
            } else if let loadFailure {
                Label(loadFailure, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(engines, id: \.releaseTag) { engine in
                    row(for: engine)
                }
            }
        } header: {
            Text("Wine engine")
        } footer: {
            Text("Changing engine replaces the installed runtime. Bottles, imported payloads and "
                + "supplied libraries are kept — they live outside it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task { await load() }
    }

    private func row(for engine: NightcapWineVersion) -> some View {
        let isCurrent = installed?.version == engine.version
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.gptkCapable == true ? "GPTK-capable engine" : "Standard engine")
                    .font(.system(.body, weight: .medium))
                Text(describe(engine))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if isCurrent {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button("Install") {
                    NotificationCenter.default.post(
                        name: .installEngineRequested,
                        object: engine.version
                    )
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    /// What taking this engine actually gets you, rather than a version alone.
    private func describe(_ engine: NightcapWineVersion) -> String {
        var parts = ["Wine \(engine.version.major).\(engine.version.minor)"]
        if engine.gptkCapable == true {
            parts.append("runs D3DMetal with your own GPTK import")
        } else {
            parts.append("newer Wine, no D3DMetal")
        }
        if let dxmt = engine.dxmtVersion {
            parts.append("DXMT \(dxmt)")
        }
        return parts.joined(separator: " · ")
    }

    private func load() async {
        defer { isLoading = false }
        installed = NightcapWineInstaller.nightcapWineInfo()

        guard let url = URL(string: DistributionConfig.versionPlistURL) else {
            loadFailure = "Could not build the manifest address."
            return
        }
        do {
            let (data, _) = try await URLSession(configuration: .ephemeral).data(from: url)
            let manifest = try PropertyListDecoder().decode(NightcapWineVersion.self, from: data)
            engines = manifest.availableEngines
        } catch {
            // Offline is the common case here and not worth an alert; the
            // section simply says nothing is known rather than looking broken.
            loadFailure = "Could not reach the engine list. \(error.localizedDescription)"
        }
    }
}
