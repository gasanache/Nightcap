//
//  BottleListEntry.swift
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

struct BottleListEntry: View {
    @Environment(NCToastCenter.self) private var toastCentre

    let bottle: Bottle
    @Binding var selected: URL?
    @Binding var refresh: Bool

    @State private var showBottleRename: Bool = false
    @State private var showBottleDuplicate: Bool = false
    @State private var name: String = ""
    @State private var runningCount: Int = 0
    @State private var hasOrphanProcesses: Bool = false
    @State private var probeTask: Task<Void, Never>?
    @State private var duplicationPhase: DuplicationPhase?

    /// The one leading marker. An unavailable bottle is `.missing` rather than
    /// the raw orange triangle it used to draw, so it reads the same as every
    /// other absent thing in the app.
    private var status: NCStatus? {
        if !bottle.isAvailable {
            .missing
        } else if runningCount > 0 {
            .running
        } else if hasOrphanProcesses {
            .unknown
        } else {
            nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            NCSidebarRow(
                title: name,
                status: status,
                caption: bottle.isAvailable ? nil : String(localized: "bottle.unavailable.caption"),
                isBusy: bottle.inFlight,
                badgeCount: runningCount,
                isDimmed: !bottle.isAvailable || bottle.inFlight
            )
            .help(hasOrphanProcesses ? String(localized: "bottle.orphan.tooltip") : "")
            if let phase = duplicationPhase {
                duplicationProgressRow(phase: phase)
            }
        }
        .onAppear {
            // The probe guards itself; this one only avoids starting a
            // sixty-second timer that would have nothing to do.
            guard bottle.isAvailable else { return }
            Task { await probeRunningState() }
            probeTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { break }
                    await probeRunningState()
                }
            }
        }
        .onDisappear {
            probeTask?.cancel()
        }
        .onChange(of: refresh, initial: true) {
            name = bottle.settings.name
            Task { await probeRunningState() }
        }
        .sheet(isPresented: $showBottleRename) {
            RenameView("rename.bottle.title", name: name) { newName in
                name = newName
                bottle.rename(newName: newName)
            }
        }
        .sheet(isPresented: $showBottleDuplicate) {
            RenameView(
                "duplicate.bottle.title",
                name: BottleOperations.nextDuplicateName(
                    baseName: name,
                    existingNames: BottleVM.shared.bottles.map(\.settings.name)
                )
            ) { newName in
                Task {
                    do {
                        let newURL = try await bottle.duplicate(newName: newName) { phase in
                            Task { @MainActor in duplicationPhase = phase }
                        }
                        await MainActor.run {
                            duplicationPhase = nil
                            selected = newURL
                            withAnimation {
                                toastCentre.show(
                                    String(
                                        format: String(localized: "status.duplicateSuccess %@"),
                                        newName
                                    ),
                                    status: .ready
                                )
                            }
                        }
                    } catch is CancellationError {
                        // The running-process guard was declined; nothing to
                        // announce.
                        await MainActor.run { duplicationPhase = nil }
                    } catch {
                        await MainActor.run {
                            duplicationPhase = nil
                            withAnimation {
                                toastCentre.show(
                                    String(
                                        format: String(localized: "status.duplicateFailed %@"),
                                        error.localizedDescription
                                    ),
                                    status: .failed
                                )
                            }
                        }
                    }
                }
            }
        }
        .contextMenu {
            Button("button.rename", systemImage: "pencil.line") {
                showBottleRename.toggle()
            }
            .disabled(!bottle.isAvailable || bottle.inFlight)
            .labelStyle(.titleAndIcon)
            Button("button.removeAlert", systemImage: "trash") {
                showRemoveAlert(bottle: bottle)
            }
            .disabled(bottle.inFlight)
            .labelStyle(.titleAndIcon)
            Divider()
            Button("button.moveBottle", systemImage: "shippingbox.and.arrow.backward") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.canCreateDirectories = true
                panel.begin { result in
                    if result == .OK {
                        if let url = panel.urls.first {
                            let newBottePath = url
                                .appending(path: bottle.url.lastPathComponent)

                            Task { @MainActor in
                                await bottle.move(destination: newBottePath)
                                selected = newBottePath
                            }
                        }
                    }
                }
            }
            .disabled(!bottle.isAvailable || bottle.inFlight)
            .labelStyle(.titleAndIcon)
            Button("button.duplicateBottle", systemImage: "doc.on.doc") {
                showBottleDuplicate.toggle()
            }
            .disabled(!bottle.isAvailable || bottle.inFlight)
            .labelStyle(.titleAndIcon)
            Button("button.exportBottle", systemImage: "arrowshape.turn.up.right") {
                let panel = NSSavePanel()
                panel.canCreateDirectories = true
                panel.allowedContentTypes = [UTType.gzip]
                panel.allowsOtherFileTypes = false
                panel.isExtensionHidden = false
                panel.nameFieldStringValue = bottle.settings.name + ".tar"
                panel.begin { result in
                    if result == .OK {
                        if let url = panel.url {
                            Task {
                                do {
                                    try await bottle.exportAsArchive(destination: url)
                                    await MainActor.run {
                                        withAnimation {
                                            toastCentre.show(
                                                String(
                                                    format: String(localized: "status.exportSuccess %@"),
                                                    bottle.settings.name
                                                ),
                                                status: .ready
                                            )
                                        }
                                    }
                                } catch {
                                    await MainActor.run {
                                        withAnimation {
                                            toastCentre.show(
                                                String(
                                                    format: String(localized: "status.exportFailed %@"),
                                                    error.localizedDescription
                                                ),
                                                status: .failed
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .disabled(!bottle.isAvailable || bottle.inFlight)
            .labelStyle(.titleAndIcon)
            Divider()
            // Deliberately NOT disabled when the bottle is unavailable: a
            // bottle Nightcap cannot find is precisely the one you want to go
            // looking for. Finder handles a missing path gracefully.
            Button("button.showInFinder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([bottle.url])
            }
            .labelStyle(.titleAndIcon)
        }
    }

    /// The guard lives here rather than at the call sites: it was on `onAppear`
    /// alone, and `onChange(of: refresh, initial: true)` walked straight past
    /// it. A bottle whose folder is gone has no wineserver to find, and every
    /// probe spawns a process.
    @MainActor
    private func probeRunningState() async {
        guard bottle.isAvailable else {
            runningCount = 0
            hasOrphanProcesses = false
            return
        }
        let trackedCount = ProcessRegistry.shared.getProcessCount(for: bottle)
        runningCount = trackedCount

        if trackedCount == 0 {
            let active = await Wine.isWineserverRunning(for: bottle)
            hasOrphanProcesses = active
        } else {
            hasOrphanProcesses = false
        }
    }
}

// MARK: - Duplication Progress & Remove Alert

extension BottleListEntry {
    func duplicationProgressRow(phase: DuplicationPhase) -> some View {
        HStack(spacing: 4) {
            switch phase {
            case .calculatingSize:
                ProgressView()
                    .controlSize(.mini)
                Text("status.duplicating.calculatingSize")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            case let .copying(bytesCopied, totalBytes):
                if totalBytes > 0, bytesCopied > 0 {
                    ProgressView(
                        value: Double(bytesCopied),
                        total: Double(totalBytes)
                    )
                    .controlSize(.mini)
                    .frame(maxWidth: 60)
                } else {
                    ProgressView()
                        .controlSize(.mini)
                }
                Text("status.duplicating.copying")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            case .updatingMetadata:
                ProgressView()
                    .controlSize(.mini)
                Text("status.duplicating.updatingMetadata")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            case .finalizing:
                ProgressView()
                    .controlSize(.mini)
                Text("status.duplicating.finalizing")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func showRemoveAlert(bottle: Bottle) {
        // The bottle name has to be substituted before the alert sees the title,
        // so the format key is resolved here and handed over already finished.
        // A resolved string is not a catalogue key, so the lookup inside
        // `ncConfirm` misses and returns it unchanged.
        let title = String(
            format: String(localized: "button.removeAlert.msg"),
            bottle.settings.name
        )
        let choice = ncConfirm(
            title: String.LocalizationValue(stringLiteral: title),
            message: String(localized: "button.removeAlert.info"),
            confirmTitle: "button.removeAlert.delete",
            isDestructive: true,
            // The checkbox only makes sense for a bottle whose files are there
            // to delete; absent it, `remember` comes back false as before.
            rememberTitle: bottle.isAvailable ? "button.removeAlert.checkbox" : nil
        )

        guard choice.confirmed else { return }

        Task(priority: .userInitiated) {
            if selected == bottle.url {
                selected = nil
            }

            await bottle.remove(delete: choice.remember)
        }
    }
}

#Preview {
    BottleListEntry(
        bottle: Bottle(bottleUrl: URL(filePath: "")),
        selected: .constant(nil),
        refresh: .constant(false)
    )
    .environment(NCToastCenter())
}
