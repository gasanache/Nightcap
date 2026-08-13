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
                // Keyed on the archive, not the tag: every engine now ships
                // from the same release, so the tag stopped being unique and
                // SwiftUI rendered the first engine once per entry.
                ForEach(engines, id: \.downloadURL) { engine in
                    row(for: engine)
                }
            }
        } header: {
            Text("Wine engine")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Changing engine replaces the installed runtime. Bottles, imported payloads and "
                    + "supplied libraries are kept — they live outside it.")
                metalChecklist
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .runtimeChanged)) { _ in
            Task { await load() }
        }
    }

    /// Metal takes two separate pieces and each screen only knows its own half,
    /// so having one without the other reads as broken. This is the one place
    /// that says what is still missing.
    @ViewBuilder
    private var metalChecklist: some View {
        let engineReady = installed?.gptkCapable == true
        let payloadReady = GPTKImporter.storedRecord() != nil
        VStack(alignment: .leading, spacing: 4) {
            Text("Direct3D 12 on Metal needs both:")
                .fontWeight(.medium)
            checklistLine(done: engineReady, text: "The GPTK-capable engine, installed above")
            checklistLine(done: payloadReady, text: "Apple's Game Porting Toolkit, imported below")
            if engineReady, payloadReady {
                Text("Both present — D3DMetal is selectable in Bottle Configuration.")
            } else {
                Text("Direct3D 11 titles reach Metal through DXMT on either engine, "
                    + "and need neither of these.")
            }
        }
    }

    private func checklistLine(done: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
            Text(text)
        }
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
    ///
    /// The number is the runtime package's, not Wine's — runtime 3.1.1 carries
    /// Wine 11 — so it is labelled as such rather than reading as a Wine
    /// version that would be years out of date.
    private func describe(_ engine: NightcapWineVersion) -> String {
        var parts = ["Runtime \(engine.version.major).\(engine.version.minor).\(engine.version.patch)"]
        if engine.gptkCapable == true {
            parts.append("older Wine, runs D3DMetal with your own GPTK import")
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
