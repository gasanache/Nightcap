//
//  SystemLibraryStoreTests.swift
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

@testable import NightcapKit
import XCTest

/// Covers the store that holds Windows libraries Nightcap is not allowed to ship.
///
/// The architecture check is the part worth pinning down: `System32` and
/// `SysWOW64` hold same-named files of different bitness, and importing the
/// wrong one fails later with a message naming some unrelated missing
/// dependency, which is exactly the confusion this store exists to prevent.
final class SystemLibraryStoreTests: XCTestCase {
    private var root: URL!
    private var store: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = URL.temporaryDirectory.appending(path: "SystemLibraryStoreTests-\(UUID().uuidString)")
        store = root.appending(path: "store")
        try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    /// A file with a valid PE header reporting `machine`, and nothing else.
    ///
    /// The store only ever reads the header, so a stub is a faithful stand-in
    /// for a multi-megabyte DLL.
    private func writePE(machine: UInt16, named name: String, in folder: URL) throws -> URL {
        var bytes = [UInt8](repeating: 0, count: 0x48)
        bytes[0] = 0x4D // M
        bytes[1] = 0x5A // Z
        bytes[0x3C] = 0x40 // e_lfanew -> 0x40
        bytes[0x40] = 0x50 // P
        bytes[0x41] = 0x45 // E
        bytes[0x44] = UInt8(machine & 0xFF)
        bytes[0x45] = UInt8(machine >> 8)
        let url = folder.appending(path: name)
        try Data(bytes).write(to: url)
        return url
    }

    private func requirement(
        _ name: String = "mstscax.dll",
        _ destination: SystemLibraryDestination = .syswow64
    ) -> SystemLibraryRequirement {
        SystemLibraryRequirement(name: name, destination: destination)
    }

    // MARK: - PE inspection

    func testDetects32BitPE() throws {
        let url = try writePE(machine: 0x014C, named: "a.dll", in: root)
        XCTAssertEqual(SystemLibraryStore.peMachineType(of: url), 0x014C)
    }

    func testDetects64BitPE() throws {
        let url = try writePE(machine: 0x8664, named: "a.dll", in: root)
        XCTAssertEqual(SystemLibraryStore.peMachineType(of: url), 0x8664)
    }

    func testRejectsNonPE() throws {
        let url = root.appending(path: "notes.txt")
        try Data("this is not a library".utf8).write(to: url)
        XCTAssertNil(SystemLibraryStore.peMachineType(of: url))
    }

    func testRejectsMissingFile() {
        XCTAssertNil(SystemLibraryStore.peMachineType(of: root.appending(path: "absent.dll")))
    }

    // MARK: - Importing

    func testImportsMatchingArchitecture() throws {
        let source = try writePE(machine: 0x014C, named: "mstscax.dll", in: root)
        try SystemLibraryStore.importLibrary(from: source, as: requirement(), inStore: store)
        XCTAssertTrue(SystemLibraryStore.has("mstscax.dll", inStore: store))
    }

    func testRejects64BitFileDestinedForSysWOW64() throws {
        let source = try writePE(machine: 0x8664, named: "mstscax.dll", in: root)
        XCTAssertThrowsError(
            try SystemLibraryStore.importLibrary(from: source, as: requirement(), inStore: store)
        ) { error in
            XCTAssertEqual(
                error as? SystemLibraryError,
                .architectureMismatch(name: "mstscax.dll", expected: .syswow64)
            )
        }
        XCTAssertFalse(SystemLibraryStore.has("mstscax.dll", inStore: store))
    }

    func testRejects32BitFileDestinedForSystem32() throws {
        let source = try writePE(machine: 0x014C, named: "x.dll", in: root)
        XCTAssertThrowsError(
            try SystemLibraryStore.importLibrary(
                from: source,
                as: requirement("x.dll", .system32),
                inStore: store
            )
        )
    }

    func testRejectsNonLibraryOnImport() throws {
        let source = root.appending(path: "mstscax.dll")
        try Data("nope".utf8).write(to: source)
        XCTAssertThrowsError(
            try SystemLibraryStore.importLibrary(from: source, as: requirement(), inStore: store)
        ) { error in
            XCTAssertEqual(error as? SystemLibraryError, .notAPortableExecutable("mstscax.dll"))
        }
    }

    /// Re-importing replaces, so supplying a corrected copy is not blocked.
    func testImportOverwritesExisting() throws {
        let first = try writePE(machine: 0x014C, named: "mstscax.dll", in: root)
        try SystemLibraryStore.importLibrary(from: first, as: requirement(), inStore: store)

        let updated = root.appending(path: "updated")
        try FileManager.default.createDirectory(at: updated, withIntermediateDirectories: true)
        let second = try writePE(machine: 0x014C, named: "mstscax.dll", in: updated)
        try Data(repeating: 0x90, count: 16).append(to: second)

        try SystemLibraryStore.importLibrary(from: second, as: requirement(), inStore: store)
        let stored = try Data(contentsOf: store.appending(path: "mstscax.dll"))
        XCTAssertEqual(stored.count, 0x48 + 16)
    }

    // MARK: - Reporting what is missing

    func testMissingReportsOnlyUnsupplied() throws {
        let source = try writePE(machine: 0x014C, named: "mstscax.dll", in: root)
        try SystemLibraryStore.importLibrary(from: source, as: requirement(), inStore: store)

        let missing = SystemLibraryStore.missing(
            from: [requirement("mstscax.dll"), requirement("devobj.dll")],
            inStore: store
        )
        XCTAssertEqual(missing.map(\.name), ["devobj.dll"])
    }

    func testMissingFromBottleIgnoresLibrariesAlreadyThere() throws {
        let bottle = root.appending(path: "bottle")
        let syswow64 = bottle.appending(path: "drive_c/windows/syswow64")
        try FileManager.default.createDirectory(at: syswow64, withIntermediateDirectories: true)
        _ = try writePE(machine: 0x014C, named: "devobj.dll", in: syswow64)

        let missing = SystemLibraryStore.missingFromBottle(
            [requirement("mstscax.dll"), requirement("devobj.dll")],
            bottleURL: bottle
        )
        XCTAssertEqual(missing.map(\.name), ["mstscax.dll"])
    }

    // MARK: - Deploying

    func testDeployPlacesLibraryInSysWOW64() throws {
        let source = try writePE(machine: 0x014C, named: "mstscax.dll", in: root)
        try SystemLibraryStore.importLibrary(from: source, as: requirement(), inStore: store)

        let bottle = root.appending(path: "bottle")
        let deployed = try SystemLibraryStore.deploy(
            [requirement()],
            toBottleAt: bottle,
            fromStore: store
        )

        XCTAssertEqual(deployed, ["mstscax.dll"])
        let landed = bottle.appending(path: "drive_c/windows/syswow64/mstscax.dll")
        XCTAssertTrue(FileManager.default.fileExists(atPath: landed.path(percentEncoded: false)))
    }

    /// A stale or wrong copy already in the prefix is replaced, not kept.
    func testDeployReplacesDifferingFile() throws {
        let source = try writePE(machine: 0x014C, named: "devobj.dll", in: root)
        try SystemLibraryStore.importLibrary(
            from: source,
            as: requirement("devobj.dll"),
            inStore: store
        )

        let bottle = root.appending(path: "bottle")
        let syswow64 = bottle.appending(path: "drive_c/windows/syswow64")
        try FileManager.default.createDirectory(at: syswow64, withIntermediateDirectories: true)
        try Data("wine builtin stub".utf8).write(to: syswow64.appending(path: "devobj.dll"))

        try SystemLibraryStore.deploy([requirement("devobj.dll")], toBottleAt: bottle, fromStore: store)

        let landed = try Data(contentsOf: syswow64.appending(path: "devobj.dll"))
        XCTAssertEqual(landed.count, 0x48)
    }

    func testDeployThrowsWhenNotSupplied() {
        XCTAssertThrowsError(
            try SystemLibraryStore.deploy(
                [requirement()],
                toBottleAt: root.appending(path: "bottle"),
                fromStore: store
            )
        ) { error in
            XCTAssertEqual(error as? SystemLibraryError, .notInStore("mstscax.dll"))
        }
    }

    // MARK: - Bottle creation

    /// Creation calls this for every new bottle, so it has to be silent about
    /// an empty store rather than throwing — a throw during creation deletes
    /// the whole bottle directory.
    func testDeployAvailableIsSilentWhenNothingSupplied() {
        let deployed = SystemLibraryStore.deployAvailable(
            toBottleAt: root.appending(path: "bottle"),
            catalog: [requirement()],
            fromStore: store
        )
        XCTAssertTrue(deployed.isEmpty)
    }

    func testDeployAvailableCopiesOnlyWhatIsSupplied() throws {
        let source = try writePE(machine: 0x014C, named: "mstscax.dll", in: root)
        try SystemLibraryStore.importLibrary(from: source, as: requirement(), inStore: store)

        let bottle = root.appending(path: "bottle")
        let deployed = SystemLibraryStore.deployAvailable(
            toBottleAt: bottle,
            catalog: [requirement("mstscax.dll"), requirement("devobj.dll")],
            fromStore: store
        )

        XCTAssertEqual(deployed, ["mstscax.dll"])
        let absent = bottle.appending(path: "drive_c/windows/syswow64/devobj.dll")
        XCTAssertFalse(FileManager.default.fileExists(atPath: absent.path(percentEncoded: false)))
    }

    /// Running on every bottle means running repeatedly on the same one when a
    /// bottle is duplicated or re-checked; an unchanged file must not be recopied.
    func testDeployAvailableIsIdempotent() throws {
        let source = try writePE(machine: 0x014C, named: "mstscax.dll", in: root)
        try SystemLibraryStore.importLibrary(from: source, as: requirement(), inStore: store)
        let bottle = root.appending(path: "bottle")
        let catalog = [requirement()]

        let first = SystemLibraryStore.deployAvailable(
            toBottleAt: bottle, catalog: catalog, fromStore: store
        )
        let second = SystemLibraryStore.deployAvailable(
            toBottleAt: bottle, catalog: catalog, fromStore: store
        )

        XCTAssertEqual(first, ["mstscax.dll"])
        XCTAssertTrue(second.isEmpty, "An unchanged library should not be copied again")
    }

    // MARK: - Catalog

    func testCatalogCoversBothRemoteControlLibraries() {
        let names = SystemLibraryCatalog.known.map(\.name)
        XCTAssertEqual(Set(names), ["mstscax.dll", "devobj.dll"])
        // Both are 32-bit, which is what makes SysWOW64 the right folder.
        XCTAssertTrue(SystemLibraryCatalog.known.allSatisfy { $0.destination == .syswow64 })
        XCTAssertTrue(SystemLibraryCatalog.known.allSatisfy { $0.sourceHint != nil })
    }

    func testCatalogLookupIsCaseInsensitive() {
        XCTAssertEqual(SystemLibraryCatalog.requirement(named: "MSTSCAX.DLL")?.name, "mstscax.dll")
        XCTAssertNil(SystemLibraryCatalog.requirement(named: "kernel32.dll"))
    }

    // MARK: - Schema

    /// The preset file is the contract; these strings are what it may contain.
    func testDestinationDecodesFromPresetJSON() throws {
        let json = """
        [{"name":"mstscax.dll","destination":"syswow64","reason":"r","sourceHint":"h"}]
        """
        let decoded = try JSONDecoder().decode([SystemLibraryRequirement].self, from: Data(json.utf8))
        XCTAssertEqual(decoded.first?.destination, .syswow64)
        XCTAssertEqual(decoded.first?.name, "mstscax.dll")
    }

    func testStoreSitsOutsideLibraries() {
        let folder = SystemLibraryStore.storeFolder(inApplicationFolder: root)
        XCTAssertEqual(folder.lastPathComponent, "SystemLibraries")
        XCTAssertNotEqual(folder.deletingLastPathComponent().lastPathComponent, "Libraries")
    }
}

private extension Data {
    /// Appends to a file on disk, for building a fixture that differs in length.
    func append(to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: self)
    }
}
