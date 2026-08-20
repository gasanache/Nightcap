//
//  GPTKSettingsSection.swift
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
import UniformTypeIdentifiers

/// Posted when the imported GPTK payload changes, so anything reporting on it
/// reloads. The Metal checklist reads the payload independently of the section
/// that imports it.
extension Notification.Name {
    static let gptkPayloadChanged = Notification.Name("gptkPayloadChanged")
}

/// Settings for Apple's Game Porting Toolkit payload: import from the
/// user-supplied disk image, show what is stored, and deploy it only when the
/// installed engine build can actually execute it.
struct GPTKSettingsSection: View {
    @State private var storedRecord: GPTKStoreRecord?
    @State private var runtimeCapable = false
    @State private var importing = false
    @State private var showImporter = false
    @State private var importError: String?

    var body: some View {
        Section {
            // One row in both states. It used to be a LabeledContent when a
            // payload was present and a bare Text when it was not, so the row
            // changed shape as you imported and the Import button moved with
            // it. Now the state is a badge, the version is the row's machine
            // slot, and the absent case fills the same line with prose.
            NCRow(
                title: String(localized: "settings.gptk.payload"),
                caption: storedRecord == nil ? String(localized: "settings.gptk.status.none") : nil,
                machine: storedRecord?.gptkVersion
            ) {
                if storedRecord != nil {
                    NCStatusBadge(status: .ready, label: "settings.gptk.status.imported")
                    Button("settings.gptk.remove", role: .destructive) {
                        removePayload()
                    }
                    .controlSize(.small)
                    .disabled(importing)
                } else {
                    NCStatusBadge(status: .missing, label: "settings.gptk.status.missing")
                }
            }

            HStack(spacing: Theme.Space.snug) {
                Button("settings.gptk.import") {
                    showImporter = true
                }
                .disabled(importing)

                // Trails the button that started the work rather than sitting
                // between two buttons and shoving the second one sideways
                // whenever an import runs.
                if importing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        } header: {
            Text("settings.gptk")
        } footer: {
            Text(runtimeCapable ? "settings.gptk.capability.ok" : "settings.gptk.capability.blocked")
                .font(Theme.Typography.rowCaption)
                .foregroundStyle(.secondary)
        }
        .task {
            await deployAndRefresh()
        }
        // A new engine may have just become capable of running the stored
        // payload, so try deploying again rather than waiting for a reopen.
        .onReceive(NotificationCenter.default.publisher(for: .runtimeChanged)) { _ in
            Task { await deployAndRefresh() }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.diskImage, .folder]
        ) { result in
            guard case let .success(url) = result else { return }
            importPayload(from: url)
        }
        .alert(
            "settings.gptk.import.failed",
            isPresented: .init(
                get: { importError != nil },
                set: {
                    if !$0 {
                        importError = nil
                    }
                }
            )
        ) {
            Button("button.ok", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    /// Deploys the stored payload if the engine can run it, then reloads what
    /// this section shows.
    private func deployAndRefresh() async {
        await Task.detached(priority: .utility) {
            GPTKImporter.deployStoredPayloadIfCapable()
        }.value
        refresh()
    }

    private func refresh() {
        storedRecord = GPTKImporter.storedRecord()
        runtimeCapable = GPTKImporter.isRuntimeGPTKCapable()
        // The Metal checklist reports on this payload but reads it separately,
        // so importing or removing one left the checklist showing the previous
        // answer until Settings was reopened.
        NotificationCenter.default.post(name: .gptkPayloadChanged, object: nil)
    }

    private func importPayload(from url: URL) {
        importing = true
        Task.detached(priority: .userInitiated) {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            var mounts: [URL] = []
            do {
                let resolved = try GPTKDiskImage.resolvePayload(at: url)
                mounts = resolved.mounts
                let payload = try GPTKImporter.validatePayload(at: resolved.libRoot)
                try GPTKImporter.importPayload(payload)
                // Deployment into the Wine tree is gated: on an engine build
                // without GPTK exception-unwind support the payload would
                // crash every process that touches it.
                if GPTKImporter.isRuntimeGPTKCapable() {
                    try GPTKImporter.deployStoredPayload()
                }
                for mount in mounts.reversed() {
                    GPTKDiskImage.detach(mount)
                }
                await MainActor.run {
                    importing = false
                    refresh()
                }
            } catch {
                for mount in mounts.reversed() {
                    GPTKDiskImage.detach(mount)
                }
                await MainActor.run {
                    importing = false
                    importError = error.localizedDescription
                    refresh()
                }
            }
        }
    }

    private func removePayload() {
        do {
            // Unconditional: isDeployed() reads files written late in deploy, so
            // a half-finished deploy looks undeployed while forwarders are
            // already swapped, and skipping cleanup would delete originals/ with
            // the store. The removal is idempotent per file.
            try GPTKImporter.removeDeployedPayload()
            try GPTKImporter.removeStore()
        } catch {
            importError = error.localizedDescription
        }
        refresh()
    }
}

/// What Direct3D 12 on Metal still needs, said in one place.
///
/// Metal takes two separate pieces and each screen only knows its own half, so
/// having one without the other reads as broken. This was a hand-drawn
/// checklist inside the engine section's *footer*, three sections below the
/// import it talks about and set in caption grey as though it were a footnote.
/// It is a section of its own now, next to the payload it is about, and each
/// line is an `NCChecklistRow` so its ticks match every other tick in the app.
struct MetalRequirementsSection: View {
    @State private var engineReady = false
    @State private var payloadReady = false

    private var bothPresent: Bool {
        engineReady && payloadReady
    }

    var body: some View {
        Section {
            NCChecklistRow(
                text: "settings.metal.engine",
                isDone: engineReady,
                // The way to satisfy the item, shown only while it is unmet —
                // an instruction beside a green tick reads like a warning.
                detail: engineReady ? nil : "settings.metal.engine.detail"
            )
            NCChecklistRow(
                text: "settings.metal.payload",
                isDone: payloadReady,
                detail: payloadReady ? nil : "settings.metal.payload.detail"
            )
        } header: {
            Text("settings.metal")
        } footer: {
            Text(bothPresent ? "settings.metal.ready" : "settings.metal.d3d11")
                .font(Theme.Typography.rowCaption)
                .foregroundStyle(.secondary)
        }
        .task { refresh() }
        // Installing an engine is the one thing that can flip the first line
        // from missing to met without this view being rebuilt.
        .onReceive(NotificationCenter.default.publisher(for: .runtimeChanged)) { _ in
            refresh()
        }
        // Importing or removing a payload is the other thing that flips a line.
        .onReceive(NotificationCenter.default.publisher(for: .gptkPayloadChanged)) { _ in
            refresh()
        }
    }

    private func refresh() {
        // Exactly what the engine footer asked before: the installed runtime's
        // `gptkCapable` flag, which is all `isRuntimeGPTKCapable()` reads.
        engineReady = GPTKImporter.isRuntimeGPTKCapable()
        payloadReady = GPTKImporter.storedRecord() != nil
    }
}
