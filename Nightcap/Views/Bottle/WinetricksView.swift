//
//  WinetricksView.swift
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

/// Pick one winetricks verb and hand it to a Terminal window.
///
/// Its heading was `.title` — the physically largest text anywhere in Nightcap,
/// outranking every real screen title — on a sheet that had no title bar of its
/// own. Its Cancel and Run were `ToolbarItem`s attached to a `TabView` inside a
/// sheet with no `NavigationStack`, so they had nowhere to render; the search
/// field was `.searchable(placement: .toolbar)` for the same absent toolbar.
/// The buttons now sit in the sheet's footer and the filter and search sit
/// beside the title, where a sheet's controls live.
///
/// The six category tabs are kept deliberately: collapsing them into one
/// searchable list is a change to how the verbs are organised, not to how they
/// are drawn, and nobody has asked for it.
struct WinetricksView: View {
    var bottle: Bottle
    @State private var winetricks: [WinetricksCategory]?
    @State private var selectedTrick: UUID?
    @State private var installedVerbs: Set<String> = []
    @State private var isLoadingInstalledVerbs = true
    @State private var verbFilter: VerbFilter = .all
    @State private var searchText: String = ""
    @Environment(\.dismiss) var dismiss

    private enum VerbFilter: String, CaseIterable {
        case all
        case installed
    }

    static let headerControlWidth: Double = 190
    /// Enough tint for the picked row to read as picked without the forced
    /// white text a filled accent block would need.
    static let selectionFill: Double = 0.18

    var body: some View {
        NCSheet(
            title: "winetricks.title",
            width: ViewWidth.large,
            height: ViewHeight.large,
            // The verb list is already a ScrollView, so the sheet must not
            // wrap it in a second one: nested, the tab strip scrolled off the
            // top of the sheet once the inner list bottomed out.
            scrolls: false,
            headerAccessory: { headerControls },
            content: { content },
            footer: { footerButtons }
        )
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in
            // Running a verb hands off to Terminal, so the tick beside it is
            // stale until we look again.
            loadInstalledVerbs()
        }
        .onAppear {
            loadCatalogue()
            loadInstalledVerbs()
        }
    }

    @ViewBuilder
    private var footerButtons: some View {
        NCFooterSpacer()
        Button("create.cancel") {
            dismiss()
        }
        .keyboardShortcut(.cancelAction)
        // Was never disabled, and did nothing at all when no verb was picked —
        // the sheet simply closed. It now says so up front.
        Button("button.run") {
            runSelectedTrick()
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(selectedTrick == nil)
    }

    // MARK: - Actions

    private func runSelectedTrick() {
        guard let selectedTrick else {
            return
        }

        let trick = winetricks?.flatMap(\.verbs)
            .first(where: { $0.id == selectedTrick })
        if let trickName = trick?.name {
            Task.detached {
                await Winetricks.runCommand(
                    command: trickName,
                    bottle: bottle
                )
            }
        }
        dismiss()
    }

    private func loadCatalogue() {
        Task.detached {
            let tricks = await Winetricks.parseVerbs()

            await MainActor.run {
                winetricks = tricks
            }
        }
    }

    private func loadInstalledVerbs() {
        Task.detached {
            let result = await Winetricks.loadInstalledVerbs(for: bottle)
            await MainActor.run {
                installedVerbs = result.verbs
                isLoadingInstalledVerbs = false
            }

            // If loaded from cache, do a background refresh
            if result.fromCache {
                await refreshInstalledVerbs()
            }
        }
    }

    private func refreshInstalledVerbs() async {
        guard let fresh = await Winetricks.listInstalledVerbs(for: bottle) else { return }
        await MainActor.run {
            installedVerbs = fresh
        }
        let bottleURL = await MainActor.run { bottle.url }
        var cache = WinetricksVerbCache(
            installedVerbs: fresh,
            lastChecked: Date()
        )
        let logInfo = WinetricksVerbCache.winetricksLogInfo(for: bottleURL)
        cache.logFileSize = logInfo.size
        cache.logFileModDate = logInfo.modDate
        try? WinetricksVerbCache.save(cache, to: bottleURL)
    }
}

// MARK: - Header Controls

extension WinetricksView {
    /// The filter and the search field, opposite the title. Both were toolbar
    /// controls on a sheet with no toolbar; this is where a sheet keeps the
    /// controls that narrow what it is showing.
    private var headerControls: some View {
        HStack(spacing: Theme.Space.snug) {
            filterPicker
                .frame(width: Self.headerControlWidth)
            searchField
                .frame(width: Self.headerControlWidth)
        }
    }

    private var filterPicker: some View {
        Picker("winetricks.filter", selection: $verbFilter) {
            Text("winetricks.filter.all")
                .tag(VerbFilter.all)
            if installedVerbs.isEmpty {
                Text("winetricks.filter.installed")
                    .tag(VerbFilter.installed)
            } else {
                Text("winetricks.filter.installedCount \(installedVerbs.count)")
                    .tag(VerbFilter.installed)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var searchField: some View {
        HStack(spacing: Theme.Space.tight) {
            Image(systemName: "magnifyingglass")
                .font(Theme.Typography.rowCaption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("winetricks.search.prompt", text: $searchText)
                .textFieldStyle(.plain)
                .font(Theme.Typography.rowCaption)
        }
        .padding(.horizontal, Theme.Space.snug)
        .padding(.vertical, Theme.Space.tight)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.inline))
    }
}

// MARK: - Body

extension WinetricksView {
    @ViewBuilder
    private var content: some View {
        if let winetricks {
            categoryTabs(winetricks)
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
        }
    }

    private func categoryTabs(_ categories: [WinetricksCategory]) -> some View {
        TabView {
            ForEach(categories, id: \.category) { category in
                verbList(for: category)
                    .tabItem {
                        let key = "winetricks.category.\(category.category.rawValue)"
                        Text(NSLocalizedString(key, comment: ""))
                    }
            }
        }
        .frame(maxHeight: .infinity)
        .overlay {
            if verbFilter == .installed, isLoadingInstalledVerbs {
                VStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("winetricks.loading.installed")
                        .font(Theme.Typography.rowCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Verb List

extension WinetricksView {
    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func filteredVerbs(for category: WinetricksCategory) -> [WinetricksVerb] {
        let base: [WinetricksVerb] = switch verbFilter {
        case .all:
            category.verbs
        case .installed:
            category.verbs.filter { installedVerbs.contains($0.name) }
        }
        let trimmed = trimmedSearch
        guard !trimmed.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.description.localizedCaseInsensitiveContains(trimmed)
        }
    }

    @ViewBuilder
    private func verbList(for category: WinetricksCategory) -> some View {
        let verbs = filteredVerbs(for: category)
        if verbs.isEmpty {
            emptyPane
        } else {
            ScrollView {
                LazyVStack(spacing: Theme.Space.tight) {
                    ForEach(verbs) { verb in
                        verbRow(verb)
                    }
                }
                .padding(Theme.Space.snug)
            }
        }
    }

    /// Two different absences, said differently: a search that matched nothing
    /// is answered by changing the search, and a category with nothing installed
    /// is answered by installing something. The table this replaces drew an
    /// empty grid with column headings for both.
    @ViewBuilder
    private var emptyPane: some View {
        if verbFilter == .installed, trimmedSearch.isEmpty {
            NCEmptyState(
                systemImage: "shippingbox",
                title: "winetricks.empty.installed.title",
                message: "winetricks.empty.installed.message"
            )
        } else {
            NCEmptyState(
                systemImage: "magnifyingglass",
                title: "winetricks.empty.noMatches.title",
                message: "winetricks.empty.noMatches.message"
            )
        }
    }

    /// The verb name is what the computer reads back, so it is monospaced; the
    /// description beside it is prose. The bare green checkmark that marked an
    /// installed verb is now the same badge every other screen uses, so it
    /// carries the word "Installed" rather than leaving a glyph to be guessed
    /// at — and read aloud rather than passed over in silence.
    private func verbRow(_ verb: WinetricksVerb) -> some View {
        let isSelected = selectedTrick == verb.id
        return Button {
            selectedTrick = verb.id
        } label: {
            NCRow(
                title: verb.name,
                caption: verb.description,
                isMachineTitle: true
            ) {
                if installedVerbs.contains(verb.name) {
                    NCStatusBadge(status: .ready, label: "dependency.installed")
                }
            }
            .padding(.horizontal, Theme.Space.snug)
            .background(isSelected ? Color.accentColor.opacity(Self.selectionFill) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.inline))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
