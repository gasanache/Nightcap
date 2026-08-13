//
//  BottleSetupRecommendationSheet+Steps.swift
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

// MARK: - Step 1: Metal

extension BottleSetupRecommendationSheet {
    /// D3DMetal is Apple's, so it cannot ship here. The user points at the
    /// Game Porting Toolkit disk image once and it is kept for every bottle.
    @ViewBuilder
    var metalStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            explanation(
                "Direct3D 12 titles run on Metal through Apple's D3DMetal, which is part of the "
                    + "Game Porting Toolkit. Apple does not allow it to be redistributed, so Nightcap "
                    + "cannot include it — download the toolkit from Apple once and point Nightcap at it."
            )

            if let gptkRecord {
                statusLine(
                    symbol: "checkmark.circle.fill",
                    tint: .green,
                    text: "D3DMetal \(gptkRecord.gptkVersion) imported"
                )
            } else if gptkImporting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading the toolkit\u{2026}").font(.caption)
                }
            } else {
                statusLine(symbol: "circle", tint: .secondary, text: "Not imported")
            }

            // Importing is only half of it, and the half the user cannot see.
            // Saying so here avoids "I imported it and nothing changed".
            if !engineIsCapable {
                note(
                    "The engine you are running cannot execute D3DMetal. Importing still stores it, "
                        + "but Direct3D 12 needs the GPTK-capable engine, which you choose in Settings. "
                        + "DXMT translates Direct3D 11 to Metal on this engine and needs none of this."
                )
            }

            if let gptkError {
                statusLine(symbol: "exclamationmark.triangle.fill", tint: .red, text: gptkError)
            }
        }
        .fileImporter(
            isPresented: $isBrowsingGPTK,
            allowedContentTypes: [.diskImage, .folder]
        ) { result in
            guard case let .success(url) = result else { return }
            importGPTK(from: url)
        }
    }
}

// MARK: - Step 2: Runtimes

extension BottleSetupRecommendationSheet {
    /// Deliberately framed as what it is — the runtimes almost every Windows
    /// program links against — rather than as any one program's requirement.
    var runtimesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            explanation(
                "Most Windows programs are built against Microsoft's Visual C++ runtimes and will "
                    + "not start without them. These download from Microsoft."
            )

            VStack(alignment: .leading, spacing: 8) {
                ForEach(runtimeChoices, id: \.id) { definition in
                    Toggle(isOn: runtimeBinding(for: definition.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(definition.displayName)
                                .font(.system(.body, weight: .medium))
                            Text(definition.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }

            if estimatedRuntimeMinutes > 0 {
                Text("About \(estimatedRuntimeMinutes) minutes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var estimatedRuntimeMinutes: Int {
        runtimeChoices
            .filter { selectedRuntimes.contains($0.id) }
            .reduce(0) { $0 + $1.estimatedInstallMinutes }
    }

    func runtimeBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selectedRuntimes.contains(id) },
            set: { isOn in
                if isOn { selectedRuntimes.insert(id) } else { selectedRuntimes.remove(id) }
            }
        )
    }

    /// One job for every selected verb, so the install runs in a single pass
    /// rather than once per component. Handed back to the caller to run after
    /// this sheet closes, not presented on top of it.
    var selectedRuntimeJob: DependencyDefinition? {
        let picked = runtimeChoices.filter { selectedRuntimes.contains($0.id) }
        guard !picked.isEmpty else { return nil }
        return DependencyDefinition(
            id: "bottle-setup-runtimes",
            displayName: "Visual C++ runtimes",
            description: picked.map(\.displayName).joined(separator: ", "),
            winetricksVerbs: picked.flatMap(\.winetricksVerbs),
            category: .runtime,
            estimatedInstallMinutes: estimatedRuntimeMinutes
        )
    }
}

// MARK: - Step 3: Windows libraries

extension BottleSetupRecommendationSheet {
    /// Named for what needs them, because nothing else does and the files have
    /// to come off a Windows PC.
    var librariesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            explanation(
                "Configuration Manager's remote control viewer (CmRcViewer.exe) needs two Windows "
                    + "libraries that Wine does not implement. Microsoft does not allow them to be "
                    + "redistributed, so they cannot be downloaded — copy them from a Windows PC and "
                    + "point Nightcap at the folder. Skip this unless you use remote control."
            )

            VStack(alignment: .leading, spacing: 6) {
                ForEach(SystemLibraryCatalog.known, id: \.name) { requirement in
                    HStack(spacing: 8) {
                        Image(systemName: librariesSupplied ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(librariesSupplied ? Color.green : Color.secondary)
                        Text(requirement.name)
                            .font(.system(.caption, design: .monospaced))
                        if let hint = requirement.sourceHint {
                            Text(hint)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }

            if !sourceFolderPath.isEmpty {
                Text("Folder: \((sourceFolderPath as NSString).abbreviatingWithTildeInPath)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let libraryError {
                statusLine(symbol: "exclamationmark.triangle.fill", tint: .red, text: libraryError)
            }
        }
        .fileImporter(isPresented: $isBrowsingLibraries, allowedContentTypes: [.folder]) { result in
            supplyLibraries(from: result)
        }
    }
}

// MARK: - Shared pieces

extension BottleSetupRecommendationSheet {
    func explanation(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    func note(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
    }

    func statusLine(symbol: String, tint: Color, text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Actions

    func refreshGPTK() {
        gptkRecord = GPTKImporter.storedRecord()
        engineIsCapable = GPTKImporter.isRuntimeGPTKCapable()
    }

    func refreshLibraries() {
        librariesSupplied = SystemLibraryStore.missing(from: SystemLibraryCatalog.known).isEmpty
    }

    /// Mirrors the Settings importer: resolve a disk image or folder, validate,
    /// store, and deploy only when the engine can actually execute it.
    func importGPTK(from url: URL) {
        gptkImporting = true
        gptkError = nil
        Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            var mounts: [URL] = []
            do {
                let resolved = try GPTKDiskImage.resolvePayload(at: url)
                mounts = resolved.mounts
                let payload = try GPTKImporter.validatePayload(at: resolved.libRoot)
                try GPTKImporter.importPayload(payload)
                if GPTKImporter.isRuntimeGPTKCapable() {
                    try GPTKImporter.deployStoredPayload()
                }
                mounts.reversed().forEach(GPTKDiskImage.detach)
                await MainActor.run {
                    gptkImporting = false
                    refreshGPTK()
                }
            } catch {
                mounts.reversed().forEach(GPTKDiskImage.detach)
                let message = error.localizedDescription
                await MainActor.run {
                    gptkImporting = false
                    gptkError = message
                    refreshGPTK()
                }
            }
        }
    }

    func supplyLibraries(from result: Result<URL, any Error>) {
        guard let folder = try? result.get() else { return }
        // Remembered, so later bottles and later installs never ask again.
        sourceFolderPath = folder.path(percentEncoded: false)
        let imported = SystemLibraryStore.autoImport(fromFolder: folder)
        refreshLibraries()

        guard librariesSupplied else {
            let missing = SystemLibraryStore.missing(from: SystemLibraryCatalog.known)
            libraryError = imported.isEmpty
                ? "No matching libraries in that folder."
                : "Still missing: " + missing.map(\.name).joined(separator: ", ")
            return
        }
        libraryError = nil
        try? SystemLibraryStore.deploy(SystemLibraryCatalog.known, toBottleAt: bottle.url)
    }
}
