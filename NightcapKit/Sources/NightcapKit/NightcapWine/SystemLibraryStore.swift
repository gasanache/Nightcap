//
//  SystemLibraryStore.swift
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

import Foundation
import os.log

/// Where a system library belongs inside a prefix.
public enum SystemLibraryDestination: String, Codable, Sendable, Equatable {
    /// 64-bit libraries.
    case system32
    /// 32-bit libraries, which is where a 32-bit program looks despite the name.
    case syswow64

    /// The PE machine type a library in this folder must be.
    var expectedMachine: UInt16 {
        switch self {
        case .system32: 0x8664
        case .syswow64: 0x014C
        }
    }

    /// Prefix-relative folder.
    var folderPath: String {
        "drive_c/windows/\(rawValue)"
    }
}

/// A Windows system library a preset needs and Nightcap cannot supply.
///
/// Some programs depend on libraries Wine does not implement and Microsoft does
/// not redistribute. Naming one here lets a preset state the dependency, check
/// it, and deploy it, without a copy of Microsoft's file ever entering this
/// repository.
public struct SystemLibraryRequirement: Codable, Sendable, Equatable, Hashable {
    /// File name as it must appear in the prefix, e.g. `"mstscax.dll"`.
    public let name: String
    /// Which Windows folder it belongs in.
    public let destination: SystemLibraryDestination
    /// Why the preset needs it, shown to whoever is asked to supply it.
    public let reason: String?
    /// Where on a Windows PC to find it, shown in the same place.
    public let sourceHint: String?

    public init(
        name: String,
        destination: SystemLibraryDestination,
        reason: String? = nil,
        sourceHint: String? = nil
    ) {
        self.name = name
        self.destination = destination
        self.reason = reason
        self.sourceHint = sourceHint
    }
}

/// The Windows libraries Nightcap knows how to place, and why they are wanted.
///
/// Only libraries listed here can be imported, because importing has to know
/// which folder a file belongs in and which architecture to insist on. Neither
/// of these has a Wine builtin, so deploying them fills a gap rather than
/// shadowing part of the runtime — which is what makes it safe to do to every
/// bottle rather than only the one bottle that needs it.
public enum SystemLibraryCatalog {
    public static let known: [SystemLibraryRequirement] = [
        SystemLibraryRequirement(
            name: "mstscax.dll",
            destination: .syswow64,
            reason: String(localized: "systemLibrary.reason.mstscax"),
            sourceHint: #"C:\Windows\SysWOW64\mstscax.dll"#
        ),
        SystemLibraryRequirement(
            name: "devobj.dll",
            destination: .syswow64,
            reason: String(localized: "systemLibrary.reason.devobj"),
            sourceHint: #"C:\Windows\SysWOW64\devobj.dll"#
        )
    ]

    /// The catalog entry for a file name, if there is one.
    public static func requirement(named name: String) -> SystemLibraryRequirement? {
        known.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}

/// Errors raised while importing or deploying a system library.
public enum SystemLibraryError: LocalizedError, Equatable {
    /// The chosen file is not a Portable Executable.
    case notAPortableExecutable(String)
    /// The chosen file is the wrong architecture for where it has to go.
    case architectureMismatch(name: String, expected: SystemLibraryDestination)
    /// The store has no copy of this library to deploy.
    case notInStore(String)

    public var errorDescription: String? {
        switch self {
        case let .notAPortableExecutable(name):
            String(localized: "systemLibrary.error.notPE \(name)")
        case let .architectureMismatch(name, expected):
            switch expected {
            case .syswow64:
                String(localized: "systemLibrary.error.need32Bit \(name)")
            case .system32:
                String(localized: "systemLibrary.error.need64Bit \(name)")
            }
        case let .notInStore(name):
            String(localized: "systemLibrary.error.notInStore \(name)")
        }
    }
}

/// Holds Windows system libraries the user supplied, and puts them into bottles.
///
/// This is the same arrangement as ``GPTKImporter``: the user provides files
/// that cannot be redistributed, Nightcap keeps them in a store outside
/// `Libraries/` so a runtime update cannot erase them, and a preset deploys
/// from that store into whichever bottle it is applied to. Importing once is
/// enough — every later bottle is served from the store.
public enum SystemLibraryStore {
    static let logger = Logger(
        subsystem: Bundle.nightcapBundleIdentifier,
        category: "SystemLibraryStore"
    )

    /// The store: `SystemLibraries/`, a sibling of `Libraries/`.
    ///
    /// Outside `Libraries/` because ``NightcapWineInstaller/install(from:)``
    /// deletes that whole folder before untarring a new runtime.
    public static var storeFolder: URL {
        storeFolder(inApplicationFolder: NightcapWineInstaller.applicationFolder)
    }

    /// Testable seam for ``storeFolder``.
    public static func storeFolder(inApplicationFolder folder: URL) -> URL {
        folder.appending(path: "SystemLibraries")
    }

    // MARK: - Inspecting

    /// Whether the store holds a library of this name.
    public static func has(_ name: String, inStore store: URL = storeFolder) -> Bool {
        FileManager.default.fileExists(atPath: store.appending(path: name).path(percentEncoded: false))
    }

    /// The requirements the store cannot currently satisfy.
    public static func missing(
        from requirements: [SystemLibraryRequirement],
        inStore store: URL = storeFolder
    ) -> [SystemLibraryRequirement] {
        requirements.filter { !has($0.name, inStore: store) }
    }

    /// The requirements a bottle is still short of, ignoring the store.
    ///
    /// A library already sitting in the prefix needs neither an import nor a
    /// deploy, so a preset applied to a prepared bottle asks for nothing.
    public static func missingFromBottle(
        _ requirements: [SystemLibraryRequirement],
        bottleURL: URL
    ) -> [SystemLibraryRequirement] {
        requirements.filter { requirement in
            let path = bottleURL
                .appending(path: requirement.destination.folderPath)
                .appending(path: requirement.name)
            return !FileManager.default.fileExists(atPath: path.path(percentEncoded: false))
        }
    }

    // MARK: - Importing

    /// Copies a user-supplied library into the store, checking it first.
    ///
    /// The architecture check is the valuable half: `System32` and `SysWOW64`
    /// hold same-named files of different bitness, and copying the wrong one
    /// produces a load failure whose message names a missing dependency rather
    /// than the real mistake.
    ///
    /// - Parameters:
    ///   - url: The file to import.
    ///   - requirement: What it is being imported as.
    ///   - store: The destination store.
    @discardableResult
    public static func importLibrary(
        from url: URL,
        as requirement: SystemLibraryRequirement,
        inStore store: URL = storeFolder
    ) throws -> URL {
        guard let machine = peMachineType(of: url) else {
            throw SystemLibraryError.notAPortableExecutable(url.lastPathComponent)
        }
        guard machine == requirement.destination.expectedMachine else {
            throw SystemLibraryError.architectureMismatch(
                name: url.lastPathComponent,
                expected: requirement.destination
            )
        }

        try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)
        let destination = store.appending(path: requirement.name)
        if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: url, to: destination)
        logger.info("Imported \(requirement.name, privacy: .public) into the system library store")
        return destination
    }

    // MARK: - Importing in bulk

    /// Imports every catalog library found in a folder, skipping what is
    /// already stored.
    ///
    /// Microsoft's licence keeps these out of the app, but nothing says the
    /// user has to be asked twice. Nominating a folder once — a copy taken off
    /// a Windows PC, or a mounted Windows volume's `SysWOW64` — lets every
    /// later install pick them up without a file picker.
    ///
    /// Only names in `catalog` are considered and each is still architecture
    /// checked, so pointing this at a folder of unrelated files imports
    /// nothing.
    ///
    /// - Returns: The names imported by this call.
    @discardableResult
    public static func autoImport(
        fromFolder folder: URL,
        catalog: [SystemLibraryRequirement] = SystemLibraryCatalog.known,
        inStore store: URL = storeFolder
    ) -> [String] {
        var imported: [String] = []
        for requirement in catalog where !has(requirement.name, inStore: store) {
            guard let source = locate(requirement.name, in: folder) else { continue }
            do {
                try importLibrary(from: source, as: requirement, inStore: store)
                imported.append(requirement.name)
            } catch {
                let reason = error.localizedDescription
                logger.error("Could not auto-import \(requirement.name, privacy: .public): \(reason, privacy: .public)")
            }
        }
        return imported
    }

    /// Finds a file by name directly in `folder`, then one level below it, so a
    /// folder holding a copied `SysWOW64` works as well as the DLLs loose.
    ///
    /// Case-insensitive: Windows filenames vary in case and the store is
    /// keyed on the catalog's spelling.
    static func locate(_ name: String, in folder: URL) -> URL? {
        let manager = FileManager.default
        guard let entries = try? manager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        else {
            return nil
        }

        if let match = entries.first(where: { $0.lastPathComponent.caseInsensitiveCompare(name) == .orderedSame }) {
            return match
        }

        for entry in entries where (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            let candidate = entry.appending(path: name)
            if manager.fileExists(atPath: candidate.path(percentEncoded: false)) {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Deploying

    /// Places the required libraries into a bottle, skipping any already there.
    ///
    /// - Returns: The names actually copied.
    @discardableResult
    public static func deploy(
        _ requirements: [SystemLibraryRequirement],
        toBottleAt bottleURL: URL,
        fromStore store: URL = storeFolder
    ) throws -> [String] {
        var deployed: [String] = []
        for requirement in requirements {
            let source = store.appending(path: requirement.name)
            guard FileManager.default.fileExists(atPath: source.path(percentEncoded: false)) else {
                throw SystemLibraryError.notInStore(requirement.name)
            }

            let folder = bottleURL.appending(path: requirement.destination.folderPath)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appending(path: requirement.name)

            // Atomic and idempotent: a library already in place with the same
            // contents is left alone, so re-running this on every bottle costs
            // nothing, and an interrupted copy can never leave the prefix
            // holding a truncated library.
            if try FileManager.default.installFileIfContentDiffers(at: destination, from: source) {
                deployed.append(requirement.name)
            }
        }
        if !deployed.isEmpty {
            logger.info("Deployed \(deployed.joined(separator: ", "), privacy: .public) into a bottle")
        }
        return deployed
    }

    /// Puts every supplied library into a newly created bottle, best effort.
    ///
    /// Called during bottle creation, where it is the same kind of step as
    /// ``BottleFontBootstrap/copySystemFonts(toPrefix:)``: useful when it works,
    /// never a reason to fail the creation. A bottle made before the user
    /// supplied anything simply gets nothing, and the Bottle Configuration
    /// section fills it in later.
    ///
    /// - Returns: The names actually copied.
    @discardableResult
    public static func deployAvailable(
        toBottleAt bottleURL: URL,
        catalog: [SystemLibraryRequirement] = SystemLibraryCatalog.known,
        fromStore store: URL = storeFolder
    ) -> [String] {
        let available = catalog.filter { has($0.name, inStore: store) }
        guard !available.isEmpty else { return [] }
        do {
            return try deploy(available, toBottleAt: bottleURL, fromStore: store)
        } catch {
            logger.error("Could not deploy system libraries: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - PE inspection

    /// The PE machine type, or nil when the file is not a PE image.
    ///
    /// `e_lfanew` at 0x3C points at the PE signature; the machine word follows
    /// it. Only the header is read, so this stays cheap on a multi-megabyte DLL.
    static func peMachineType(of url: URL) -> UInt16? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 0x40), header.count == 0x40 else { return nil }
        guard header[0] == 0x4D, header[1] == 0x5A else { return nil } // "MZ"

        let peOffset = header[0x3C ..< 0x40].withUnsafeBytes { raw in
            UInt32(littleEndian: raw.loadUnaligned(as: UInt32.self))
        }

        try? handle.seek(toOffset: UInt64(peOffset))
        guard let signature = try? handle.read(upToCount: 6), signature.count == 6 else { return nil }
        guard signature[0] == 0x50, signature[1] == 0x45 else { return nil } // "PE"

        return signature[4 ..< 6].withUnsafeBytes { raw in
            UInt16(littleEndian: raw.loadUnaligned(as: UInt16.self))
        }
    }
}
