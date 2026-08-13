//
//  GameConfigDependencyTests.swift
//  NightcapKitTests
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

@testable import NightcapKit
import XCTest

/// Covers the bridge that turns a preset's winetricks verbs into something the
/// install UI can run. Applying a preset used to record its verbs and install
/// nothing; these tests pin down that the verbs are actually requested.
final class GameConfigDependencyTests: XCTestCase {
    // MARK: - Fixtures

    private func makeVariant(verbs: [String]?) -> GameConfigVariant {
        GameConfigVariant(
            id: "test-variant",
            label: "Test Variant",
            isDefault: true,
            settings: GameConfigVariantSettings(),
            winetricksVerbs: verbs
        )
    }

    private func makeEntry(verbs: [String]?) -> GameDBEntry {
        GameDBEntry(
            id: "test-game",
            title: "Test Game",
            rating: .playable,
            variants: [makeVariant(verbs: verbs)]
        )
    }

    // MARK: - Nothing to install

    func testNoVerbsRequestsNothing() {
        let entry = makeEntry(verbs: nil)
        XCTAssertNil(GameConfigDependency.pendingInstall(
            entry: entry,
            variant: entry.variants[0],
            installedVerbs: []
        ))
    }

    func testEmptyVerbListRequestsNothing() {
        let entry = makeEntry(verbs: [])
        XCTAssertNil(GameConfigDependency.pendingInstall(
            entry: entry,
            variant: entry.variants[0],
            installedVerbs: []
        ))
    }

    func testAlreadyInstalledVerbsRequestNothing() {
        let entry = makeEntry(verbs: ["vcrun2013", "dotnet48"])
        XCTAssertNil(GameConfigDependency.pendingInstall(
            entry: entry,
            variant: entry.variants[0],
            installedVerbs: ["vcrun2013", "dotnet48", "xact"]
        ))
    }

    // MARK: - Missing verbs

    func testMissingVerbsAreRequested() {
        let entry = makeEntry(verbs: ["vcrun2013"])
        let pending = GameConfigDependency.pendingInstall(
            entry: entry,
            variant: entry.variants[0],
            installedVerbs: []
        )
        XCTAssertEqual(pending?.winetricksVerbs, ["vcrun2013"])
    }

    func testOnlyMissingVerbsAreRequested() {
        let entry = makeEntry(verbs: ["vcrun2013", "dotnet48", "xact"])
        let pending = GameConfigDependency.pendingInstall(
            entry: entry,
            variant: entry.variants[0],
            installedVerbs: ["dotnet48"]
        )
        XCTAssertEqual(pending?.winetricksVerbs, ["vcrun2013", "xact"])
    }

    func testUnknownVerbSetSynthesisesDefinitionFromEntry() {
        let entry = makeEntry(verbs: ["quartz", "wmp11"])
        let pending = GameConfigDependency.pendingInstall(
            entry: entry,
            variant: entry.variants[0],
            installedVerbs: []
        )
        XCTAssertEqual(pending?.id, "gamedb-test-game")
        XCTAssertEqual(pending?.displayName, "Test Game")
        XCTAssertEqual(pending?.winetricksVerbs, ["quartz", "wmp11"])
    }

    /// A pending set that matches a standard dependency reuses it, so the install
    /// sheet shows the real component name rather than the game's title.
    func testMatchingStandardDependencyIsReused() {
        let entry = makeEntry(verbs: ["vcrun2013"])
        let pending = GameConfigDependency.pendingInstall(
            entry: entry,
            variant: entry.variants[0],
            installedVerbs: []
        )
        XCTAssertEqual(pending?.id, "vcrun2013")
        XCTAssertEqual(pending?.displayName, "Visual C++ 2013 Runtime")
    }

    // MARK: - Standard dependency catalogue

    func testStandardDependenciesIncludeVCRun2013() {
        let definition = DependencyDefinition.standardDependencies.first { $0.id == "vcrun2013" }
        XCTAssertNotNil(definition, "vcrun2013 is missing from the standard dependency list")
        XCTAssertEqual(definition?.winetricksVerbs, ["vcrun2013"])
        XCTAssertEqual(definition?.category, .runtime)
        XCTAssertFalse(definition?.description.isEmpty ?? true)
    }

    func testStandardDependencyIdsAreUnique() {
        let ids = DependencyDefinition.standardDependencies.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate dependency definition IDs")
    }

    func testBundledEntriesAreSortedByTitle() {
        let titles = GameDBLoader.loadDefaults().map(\.title)
        XCTAssertEqual(titles, titles.sorted(), "GameDB.json entries must stay sorted by title")
    }
}
