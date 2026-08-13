//
//  SystemLibraryConfigSection.swift
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

/// Windows libraries section for the bottle Config view.
///
/// Sits beside ``DependencyConfigSection``, and covers the dependencies that
/// are not winetricks verbs: Windows libraries Wine does not implement and
/// Microsoft does not redistribute. Nightcap cannot ship them, so the user
/// supplies a copy once; it is kept outside the runtime folder and placed into
/// every bottle created afterwards. This section is what fixes up the bottles
/// that already exist.
struct SystemLibraryConfigSection: View {
    @ObservedObject var bottle: Bottle

    @State private var inBottle: Set<String> = []
    @State private var inStore: Set<String> = []
    @State private var importTarget: SystemLibraryRequirement?
    @State private var isImporting: Bool = false
    @State private var isChoosingFolder: Bool = false
    @State private var errorMessage: String?
    /// A folder to pick these up from without being asked again. Microsoft's
    /// licence stops the libraries shipping inside the app; it does not stop
    /// the app remembering where the user keeps them.
    @AppStorage("systemLibrarySourceFolder") private var sourceFolderPath: String = ""

    private var catalog: [SystemLibraryRequirement] { SystemLibraryCatalog.known }

    var body: some View {
        Section {
            ForEach(catalog, id: \.name) { requirement in
                libraryRow(requirement)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import automatically from")
                        .font(.caption)
                    Text(sourceFolderPath.isEmpty
                        ? "No folder chosen — you will be asked for each library"
                        : abbreviatedSourcePath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                if !sourceFolderPath.isEmpty {
                    Button("Forget") { sourceFolderPath = "" }
                        .controlSize(.small)
                }
                Button(sourceFolderPath.isEmpty ? "Choose\u{2026}" : "Change\u{2026}") {
                    isChoosingFolder = true
                }
                .controlSize(.small)
            }

            Text(
                "Microsoft does not permit these to be redistributed, so Nightcap cannot include them. "
                    + "Point it at a folder holding them — a copy from a Windows PC, or a mounted "
                    + "Windows volume — and they are picked up on their own from then on."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        } header: {
            HStack {
                Label("Windows Libraries", systemImage: "building.columns")
                Spacer()
                Button {
                    refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Re-check which libraries are in this bottle")
            }
        }
        // Keyed on the bottle rather than onAppear: switching bottles in the
        // sidebar reuses this view, and onAppear would not fire again, leaving
        // the previous bottle's status on screen.
        .task(id: bottle.url) {
            // An error raised against the previous bottle does not apply here.
            errorMessage = nil
            runAutoImport()
            refresh()
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.data]) { result in
            if let target = importTarget {
                performImport(result, as: target)
            }
            importTarget = nil
        }
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            guard let url = try? result.get() else { return }
            sourceFolderPath = url.path(percentEncoded: false)
            runAutoImport()
        }
    }

    // MARK: - Row

    private func libraryRow(_ requirement: SystemLibraryRequirement) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(requirement.name)
                        .font(.system(.body, design: .monospaced))
                    if let reason = requirement.reason {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                statusBadge(for: requirement)
                actionButton(for: requirement)
            }

            // Only worth showing while it is still missing; once supplied,
            // repeating where it came from is noise.
            if !inStore.contains(requirement.name), let hint = requirement.sourceHint {
                Text("Copy from \(hint)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusBadge(for requirement: SystemLibraryRequirement) -> some View {
        if inBottle.contains(requirement.name) {
            Label("Installed", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else if inStore.contains(requirement.name) {
            Label("Supplied", systemImage: "tray.full.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        } else {
            Label("Not Supplied", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func actionButton(for requirement: SystemLibraryRequirement) -> some View {
        if inBottle.contains(requirement.name) {
            EmptyView()
        } else if inStore.contains(requirement.name) {
            Button("Install") {
                install(requirement)
            }
            .controlSize(.small)
        } else {
            Button("Supply\u{2026}") {
                importTarget = requirement
                isImporting = true
            }
            .controlSize(.small)
        }
    }

    // MARK: - Actions

    /// Path with the home directory shortened, so a long path stays readable.
    private var abbreviatedSourcePath: String {
        (sourceFolderPath as NSString).abbreviatingWithTildeInPath
    }

    /// Pulls anything missing out of the nominated folder, then puts it into
    /// this bottle. Silent by design: this runs on every appearance and has
    /// nothing to say when the folder is unset or already exhausted.
    private func runAutoImport() {
        guard !sourceFolderPath.isEmpty else { return }
        let folder = URL(fileURLWithPath: sourceFolderPath)
        let imported = SystemLibraryStore.autoImport(fromFolder: folder)
        guard !imported.isEmpty else { return }
        refresh()
        for requirement in SystemLibraryCatalog.known where imported.contains(requirement.name) {
            install(requirement)
        }
    }

    private func refresh() {
        let missing = Set(
            SystemLibraryStore.missingFromBottle(catalog, bottleURL: bottle.url).map(\.name)
        )
        inBottle = Set(catalog.map(\.name)).subtracting(missing)
        inStore = Set(catalog.map(\.name).filter { SystemLibraryStore.has($0) })
    }

    private func performImport(_ result: Result<URL, any Error>, as requirement: SystemLibraryRequirement) {
        do {
            let url = try result.get()
            // A file chosen outside the app's own folders is security-scoped.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            try SystemLibraryStore.importLibrary(from: url, as: requirement)
            errorMessage = nil
            // Supplying it is almost always in order to use it here, so put it
            // straight into this bottle rather than making that a second step.
            install(requirement)
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    private func install(_ requirement: SystemLibraryRequirement) {
        do {
            try SystemLibraryStore.deploy([requirement], toBottleAt: bottle.url)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }
}
