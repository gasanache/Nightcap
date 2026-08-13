//
//  GameConfigurationView.swift
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

/// Browses the preset catalogue and applies entries to the bottle.
///
/// Rows navigate through an item binding instead of `NavigationLink` rows in a
/// `List`: the List keeps a popped row selected, so link rows go dead when the
/// same row is clicked twice. The system resets the item binding to nil on
/// pop, which keeps every click live.
struct GameConfigurationView: View {
    @ObservedObject var bottle: Bottle
    @State private var entries: [GameDBEntry] = []
    @State private var searchText: String = ""
    @State private var openEntryID: String?

    private var visibleEntries: [GameDBEntry] {
        searchText.isEmpty ? entries : GameMatcher.searchEntries(searchText, in: entries)
    }

    var body: some View {
        List {
            if visibleEntries.isEmpty {
                emptyStateView
                    .accessibilityIdentifier("gamedb.emptyState")
            } else {
                ForEach(visibleEntries, id: \.id) { entry in
                    Button {
                        openEntryID = entry.id
                    } label: {
                        GameEntryRowView(entry: entry)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("gamedb.row.\(entry.id)")
                }
            }
        }
        .accessibilityIdentifier("gamedb.list")
        .searchable(text: $searchText, prompt: "gamedb.search.prompt")
        .navigationTitle("gamedb.title")
        .navigationDestination(item: $openEntryID) { entryID in
            if let entry = entries.first(where: { $0.id == entryID }) {
                GameEntryDetailView(entry: entry, bottle: bottle)
            }
        }
        .onAppear {
            entries = GameDBLoader.loadDefaults()
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label {
                if searchText.isEmpty {
                    Text("gamedb.empty.noData")
                } else {
                    Text("gamedb.empty.noResults \(searchText)")
                }
            } icon: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
