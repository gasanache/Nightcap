//
//  ProgramsView.swift
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

struct ProgramsView: View {
    @ObservedObject var bottle: Bottle
    @State private var blocklist: [URL] = []
    @State private var selectedPrograms = Set<Program>()
    @State private var selectedBlockitems = Set<URL>()
    @Binding var path: NavigationPath
    @State private var sortedPrograms: [Program] = []
    @State private var resortPrograms = false
    @State private var searchText = ""

    @AppStorage("areProgramsExpanded") private var areProgramsExpanded = true
    @AppStorage("isBlocklistExpanded") private var isBlocklistExpanded = false

    private var searchResults: [Program] {
        guard !searchText.isEmpty else { return sortedPrograms }
        return sortedPrograms.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var searchedBlocklists: [URL] {
        guard !searchText.isEmpty else { return blocklist }
        return blocklist.filter { $0.absoluteString.localizedCaseInsensitiveContains(searchText) }
    }

    private var selectedSearchedPrograms: [Program] {
        searchResults.filter { selectedPrograms.contains($0) }
    }

    var body: some View {
        Form {
            programsSection
            blocklistSection
        }
        .formStyle(.grouped)
        .animation(.nightcapDefault, value: sortedPrograms)
        .animation(.nightcapDefault, value: bottle.settings.blocklist)
        .animation(.nightcapDefault, value: searchText)
        .animation(.nightcapDefault, value: areProgramsExpanded)
        .animation(.nightcapDefault, value: isBlocklistExpanded)
        .navigationTitle("tab.programs")
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if bottle.programsLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    rescanButton
                }
            }
        }
        .onAppear {
            loadData()
        }
        .onChange(of: resortPrograms) {
            loadPrograms()
        }
        .onChange(of: bottle.programs) {
            loadData()
        }
        .onChange(of: bottle.settings) {
            loadData()
        }
    }

    /// Labelled "Rescan ClickOnce Apps" while calling `updateInstalledPrograms()`,
    /// which rescans every program in the bottle. The label now says that.
    private var rescanButton: some View {
        Button {
            Task {
                await bottle.updateInstalledPrograms()
                loadData()
            }
        } label: {
            Label(String(localized: "program.rescan"), systemImage: "arrow.clockwise")
        }
        .help("program.rescan")
    }

    private func loadData() {
        loadPrograms()
        blocklist = bottle.settings.blocklist.filter {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    private func loadPrograms() {
        let programs = bottle.programs.filter {
            FileManager.default.fileExists(atPath: $0.url.path(percentEncoded: false))
        }
        sortedPrograms = [
            programs.pinned.sorted { $0.name < $1.name },
            programs.unpinned.sorted { $0.name < $1.name }
        ].flatMap { $0 }
    }
}

// MARK: - Sections

extension ProgramsView {
    private var programsSection: some View {
        Section("program.title", isExpanded: $areProgramsExpanded) {
            if searchResults.isEmpty {
                programsEmptyState
            } else {
                List(searchResults, id: \.self, selection: $selectedPrograms) { program in
                    ProgramItemView(
                        bottle: bottle, program: program, path: $path
                    )
                    .contextMenu {
                        programContextMenu(for: program)
                    }
                }
            }
        }
        .animation(.nightcapDefault, value: sortedPrograms)
    }

    private var blocklistSection: some View {
        Section("program.blocklist", isExpanded: $isBlocklistExpanded) {
            if searchedBlocklists.isEmpty {
                blocklistEmptyState
            } else {
                List(searchedBlocklists, id: \.self, selection: $selectedBlockitems) { blockedUrl in
                    BlocklistItemView(blockedUrl: blockedUrl, bottle: bottle)
                        .contextMenu {
                            blocklistContextMenu(for: blockedUrl)
                        }
                }
            }
        }
    }

    /// An expanded section drawing nothing said neither whether the scan found
    /// anything nor whether the search was to blame — two states with two
    /// different ways out, so they read differently.
    private var programsEmptyState: some View {
        NCEmptyState(
            systemImage: searchText.isEmpty ? "app.dashed" : "magnifyingglass",
            title: searchText.isEmpty ? "program.empty.title" : "program.empty.noResults",
            message: searchText.isEmpty ? "program.empty.message" : nil
        )
    }

    private var blocklistEmptyState: some View {
        NCEmptyState(
            systemImage: searchText.isEmpty ? "hand.raised" : "magnifyingglass",
            title: searchText.isEmpty ? "program.blocklist.empty.title" : "program.empty.noResults",
            message: searchText.isEmpty ? "program.blocklist.empty.message" : nil
        )
    }
}

// MARK: - Context Menus

extension ProgramsView {
    @ViewBuilder
    private func programContextMenu(for program: Program) -> some View {
        let selectedPrograms = selectedSearchedPrograms
        if selectedPrograms.contains(program), selectedPrograms.count > 1 {
            Button("program.add.selected.blocklist", systemImage: "hand.raised") {
                let existing = Set(bottle.settings.blocklist)
                let additions = selectedPrograms.map(\.url).filter { !existing.contains($0) }
                bottle.settings.blocklist.append(contentsOf: additions)
                blocklist = bottle.settings.blocklist
            }
            .labelStyle(.titleAndIcon)
        } else {
            ProgramMenuView(program: program, path: $path)

            Section {
                Button("program.add.blocklist", systemImage: "hand.raised") {
                    if !bottle.settings.blocklist.contains(program.url) {
                        bottle.settings.blocklist.append(program.url)
                    }
                    blocklist = bottle.settings.blocklist
                }
                .labelStyle(.titleAndIcon)
            }
        }
    }

    @ViewBuilder
    private func blocklistContextMenu(for blockedUrl: URL) -> some View {
        if selectedBlockitems.contains(blockedUrl) {
            Button("program.remove.selected.blocklist", systemImage: "hand.raised") {
                bottle.settings.blocklist.removeAll(where: { selectedBlockitems.contains($0) })
                blocklist = bottle.settings.blocklist
            }
            .labelStyle(.titleAndIcon)
            .symbolVariant(.slash)
        } else {
            Button("program.remove.blocklist", systemImage: "hand.raised") {
                bottle.settings.blocklist.removeAll(where: { $0 == blockedUrl })
                blocklist = bottle.settings.blocklist
            }
            .labelStyle(.titleAndIcon)
            .symbolVariant(.slash)
        }
    }
}

// MARK: - Program Row

/// One program in the list.
///
/// Everything except the name used to sit behind `showButtons`, set on hover,
/// so at rest the row was a name and nothing else: no pin, no architecture, no
/// sign that a program overrode the bottle's graphics, and no way to reach
/// Configure or Run without a mouse. The controls are permanent now — hover
/// only changes the pin glyph, which says what the click will do.
struct ProgramItemView: View {
    @Environment(NCToastCenter.self) private var toastCentre

    @ObservedObject var bottle: Bottle
    @ObservedObject var program: Program
    @Binding var path: NavigationPath
    @State private var pinHovered = false
    @State private var isLaunching = false

    var body: some View {
        HStack(spacing: Theme.Space.snug) {
            pinButton
            Text(program.name)
                .frame(maxWidth: .infinity, alignment: .leading)
            tag
            if program.settings.overrides?.graphicsBackend != nil {
                overrideBadge
            }
            configButton
            runButton
        }
        .padding(Theme.Space.tight)
    }

    private var pinButton: some View {
        Button {
            program.pinned.toggle()
        } label: {
            Image(systemName: "pin")
                .onHover { hover in
                    pinHovered = hover
                }
                .symbolVariant(program.pinned ? pinHovered ? .slash.fill : .fill : .none)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .foregroundStyle(program.pinned ? Color.accentColor : Color.secondary)
    }

    /// A program is either a PE binary with an architecture or a ClickOnce
    /// deployment, so the row carries at most one chip.
    @ViewBuilder
    private var tag: some View {
        if let peFile = program.peFile,
           let archString = peFile.architecture.toString() {
            ProgramTag(text: archString)
        } else if program.isClickOnce {
            ProgramTag(
                text: "ClickOnce",
                accessibilityLabel: String(localized: "program.clickonce.badge")
            )
        }
    }

    /// The override was a bare blue slider glyph — the one thing in the row
    /// that changes how the program launches, and the only way to learn what it
    /// meant was to hover it. The badge names it, and the override is in place
    /// and in effect, so `.ready`.
    private var overrideBadge: some View {
        NCStatusBadge(status: .ready, label: "program.overrides.badge")
            .help("program.graphics.overridden")
    }

    private var configButton: some View {
        Button("program.config", systemImage: "gearshape") {
            path.append(program)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("program.config")
    }

    private var runButton: some View {
        Button("button.run", systemImage: "play") {
            launchProgram()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(isLaunching ? Color.accentColor : Color.secondary)
        .disabled(isLaunching)
        .help("button.run")
    }

    private func launchProgram() {
        isLaunching = true
        // Capture modifier flags synchronously before entering async context
        let useTerminal = NSEvent.modifierFlags.contains(.shift)

        // Check clipboard before launch (blocking alert for needsUserDecision is handled internally)
        let clipResult = program.performClipboardCheck()
        if case let .autoCleared(contentType, sizeBytes) = clipResult {
            let sizeKB = String(format: "%.1f", Double(sizeBytes) / 1_024.0)
            withAnimation {
                toastCentre.show(
                    String(localized: "clipboard.cleared.toast")
                        .replacingOccurrences(of: "{contentType}", with: contentType)
                        .replacingOccurrences(of: "{sizeKB}", with: sizeKB),
                    status: .available
                )
            }
        }

        Task {
            let result = await program.launchWithUserMode(useTerminal: useTerminal)
            withAnimation {
                result.announce(on: toastCentre)
            }
            isLaunching = false
        }
    }
}

/// The one stroked chip a program row carries.
///
/// The row drew this twice, four lines apart — architecture and ClickOnce —
/// each restating a 5pt inset, a radius of 4 and a `.secondary` stroke, and
/// only one setting a font, so the two chips were different sizes. Both hold
/// something read off the executable, so both are machine text.
private struct ProgramTag: View {
    /// Read off the binary at runtime — `String`, not a key.
    let text: String
    /// ClickOnce is a product name rather than a word, so the row supplies a
    /// spoken label for it.
    var accessibilityLabel: String?

    var body: some View {
        Text(text)
            .font(Theme.Typography.machine)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Theme.Space.tight)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.inline)
                    .stroke(.secondary)
            )
            .accessibilityLabel(accessibilityLabel ?? text)
    }
}

// MARK: - Blocklist Row

/// One blocked path.
///
/// The path was prose in the row's title position, which is the one thing it is
/// not. The filename is the subject; the path under it is machine text,
/// middle-truncated so both ends stay legible.
struct BlocklistItemView: View {
    let blockedUrl: URL
    @ObservedObject var bottle: Bottle

    var body: some View {
        NCRow(
            title: blockedUrl.lastPathComponent,
            machine: blockedUrl.prettyPath(bottle)
        ) {
            Button("program.remove.blocklist", systemImage: "xmark") {
                bottle.settings.blocklist.removeAll { $0 == blockedUrl }
            }
            .labelStyle(.iconOnly)
            .symbolVariant(.fill.circle)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("program.remove.blocklist")
        }
    }
}
