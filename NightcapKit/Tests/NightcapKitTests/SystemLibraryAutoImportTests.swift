//
//  SystemLibraryAutoImportTests.swift
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

/// Covers picking Windows libraries up from a nominated folder.
///
/// Microsoft's licence keeps these out of the app, so the user supplies them.
/// This is what stops the app asking twice: point it at a folder once and every
/// later install imports from it unattended. Because it runs unattended, the
/// guards matter more than the happy path — it must ignore anything not in the
/// catalog, refuse the wrong architecture, and do nothing on a second pass.
final class SystemLibraryAutoImportTests: XCTestCase {
    private var root: URL!
    private var store: URL!
    private var source: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = URL.temporaryDirectory.appending(path: "SystemLibraryAutoImport-\(UUID().uuidString)")
        store = root.appending(path: "store")
        source = root.appending(path: "supplied")
        try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        try super.tearDownWithError()
    }

    /// A file with a valid PE header reporting `machine`, and nothing else.
    @discardableResult
    private func writePE(machine: UInt16, named name: String, in folder: URL) throws -> URL {
        var bytes = [UInt8](repeating: 0, count: 0x48)
        bytes[0] = 0x4D
        bytes[1] = 0x5A
        bytes[0x3C] = 0x40
        bytes[0x40] = 0x50
        bytes[0x41] = 0x45
        bytes[0x44] = UInt8(machine & 0xFF)
        bytes[0x45] = UInt8(machine >> 8)
        let url = folder.appending(path: name)
        try Data(bytes).write(to: url)
        return url
    }

    private func requirement(_ name: String = "mstscax.dll") -> SystemLibraryRequirement {
        SystemLibraryRequirement(name: name, destination: .syswow64)
    }

    private func autoImport(_ catalog: [SystemLibraryRequirement], from folder: URL? = nil) -> [String] {
        SystemLibraryStore.autoImport(
            fromFolder: folder ?? source,
            catalog: catalog,
            inStore: store
        )
    }

    // MARK: - Happy path

    func testTakesCatalogLibrariesFromAFolder() throws {
        try writePE(machine: 0x014C, named: "mstscax.dll", in: source)
        try writePE(machine: 0x014C, named: "devobj.dll", in: source)

        let imported = autoImport([requirement("mstscax.dll"), requirement("devobj.dll")])
        XCTAssertEqual(Set(imported), ["mstscax.dll", "devobj.dll"])
    }

    /// A copied `SysWOW64` folder should work as well as loose files.
    func testLooksOneLevelDown() throws {
        let nested = source.appending(path: "SysWOW64")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try writePE(machine: 0x014C, named: "mstscax.dll", in: nested)

        XCTAssertEqual(autoImport([requirement()]), ["mstscax.dll"])
    }

    /// Windows filenames vary in case; the store is keyed on the catalog's.
    func testMatchesNameCaseInsensitively() throws {
        try writePE(machine: 0x014C, named: "MSTSCAX.DLL", in: source)

        XCTAssertEqual(autoImport([requirement()]), ["mstscax.dll"])
        XCTAssertTrue(SystemLibraryStore.has("mstscax.dll", inStore: store))
    }

    // MARK: - Guards

    /// This runs on every appearance, so a second pass must copy nothing.
    func testSkipsWhatIsAlreadyStored() throws {
        try writePE(machine: 0x014C, named: "mstscax.dll", in: source)

        XCTAssertEqual(autoImport([requirement()]), ["mstscax.dll"])
        XCTAssertTrue(autoImport([requirement()]).isEmpty)
    }

    func testIgnoresFilesNotInTheCatalog() throws {
        try writePE(machine: 0x014C, named: "somethingelse.dll", in: source)

        XCTAssertTrue(autoImport([requirement()]).isEmpty)
    }

    func testRejectsWrongArchitecture() throws {
        try writePE(machine: 0x8664, named: "mstscax.dll", in: source)

        XCTAssertTrue(autoImport([requirement()]).isEmpty)
        XCTAssertFalse(SystemLibraryStore.has("mstscax.dll", inStore: store))
    }

    func testIgnoresSomethingThatIsNotALibrary() throws {
        try Data("not a dll".utf8).write(to: source.appending(path: "mstscax.dll"))

        XCTAssertTrue(autoImport([requirement()]).isEmpty)
    }

    /// The nominated folder can be deleted or on an unmounted volume.
    func testMissingFolderIsHarmless() {
        XCTAssertTrue(autoImport([requirement()], from: root.appending(path: "nope")).isEmpty)
    }

    // MARK: - Locating

    func testLocateFindsALooseFile() throws {
        try writePE(machine: 0x014C, named: "devobj.dll", in: source)
        XCTAssertNotNil(SystemLibraryStore.locate("devobj.dll", in: source))
    }

    func testLocateReturnsNilWhenAbsent() {
        XCTAssertNil(SystemLibraryStore.locate("devobj.dll", in: source))
    }
}
