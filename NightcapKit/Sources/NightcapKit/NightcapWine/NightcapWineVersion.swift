//
//  NightcapWineVersion.swift
//  NightcapKit
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
import SemanticVersion

/// Represents the version information structure from WhiskyWineVersion.plist
/// The plist format uses a nested dictionary structure:
/// ```
/// <key>version</key>
/// <dict>
///     <key>major</key>
///     <integer>2</integer>
///     <key>minor</key>
///     <integer>5</integer>
///     <key>patch</key>
///     <integer>0</integer>
/// </dict>
/// ```
public struct NightcapWineVersion: Codable {
    public var version: SemanticVersion

    /// The bundled DXVK (macOS) version recorded alongside the runtime version,
    /// e.g. `"1.10.3"`. Optional so runtime plists written before this key
    /// existed still decode.
    public var dxvkVersion: String?

    /// The bundled DXMT version recorded alongside the runtime version,
    /// e.g. `"0.80"`. Optional so runtime plists from before v3.1.0 (which
    /// introduced the DXMT payload) still decode; `nil` also signals to the
    /// app that the installed runtime cannot offer the DXMT backend.
    public var dxmtVersion: String?

    /// The expected SHA-256 of the `Libraries.tar.gz` archive for this runtime
    /// version, as a lowercase hex string. When present, the downloader verifies
    /// the fetched archive against it before installing. Optional so runtime
    /// plists written before this key existed still decode (and so the download
    /// path stays backward-compatible when no hash is advertised).
    public var sha256: String?

    /// Whether this runtime's Wine build can execute Apple's GPTK/D3DMetal
    /// payload. The payload's forwarder DLLs are C++ with exception handling,
    /// and unwinding them requires personality-routine support for builtin
    /// modules that upstream Wine lacks — on a build without it, every process
    /// that runs D3DMetal code dies on its first internal throw. Absent (all
    /// runtimes to date) means not capable; a future GPTK-ready runtime build
    /// advertises `true` here.
    public var gptkCapable: Bool?

    /// The release tag holding this engine's `Libraries.tar.gz`, when it is not
    /// simply `v<major>.<minor>.<patch>`.
    ///
    /// A pre-release tag such as `v4.0.0-beta.2` cannot be reconstructed from
    /// the three version integers, so it has to be stated. Absent means the
    /// conventional tag.
    public var tag: String?

    /// The asset filename inside that release, when it is not the conventional
    /// `Libraries.tar.gz`.
    ///
    /// One release holding every engine cannot give them all the same filename,
    /// so each states its own.
    public var asset: String?

    /// Other engines this manifest offers, when there is more than one.
    ///
    /// The engines are a trade rather than a progression: the default is newer
    /// Wine, and a GPTK-capable build is older Wine that can execute Apple's
    /// D3DMetal. Listing them lets the app offer the choice instead of the user
    /// installing a runtime by hand. Entries carry the same fields as the root,
    /// so each states its own hash, tag and capabilities.
    public var engines: [NightcapWineVersion]?

    /// Everything installable, the root entry first.
    ///
    /// The root stays the default engine so an older build, which knows nothing
    /// about `engines`, keeps resolving exactly what it did before.
    public var availableEngines: [NightcapWineVersion] {
        var root = self
        root.engines = nil
        return [root] + (engines ?? [])
    }

    /// The release tag to fetch this engine's archive from.
    public var releaseTag: String {
        tag ?? "v\(version.major).\(version.minor).\(version.patch)"
    }

    /// The asset filename to fetch from that release.
    public var assetName: String {
        asset ?? "Libraries.tar.gz"
    }

    /// Where this engine's archive actually lives.
    public var downloadURL: String {
        DistributionConfig.librariesURL(tag: releaseTag, asset: assetName)
    }

    enum CodingKeys: String, CodingKey {
        case version
        case dxvkVersion
        case dxmtVersion
        case sha256
        case gptkCapable
        case tag
        case asset
        case engines
    }

    public init(
        version: SemanticVersion,
        dxvkVersion: String? = nil,
        dxmtVersion: String? = nil,
        sha256: String? = nil,
        gptkCapable: Bool? = nil
    ) {
        self.version = version
        self.dxvkVersion = Self.normalized(dxvkVersion)
        self.dxmtVersion = Self.normalized(dxmtVersion)
        self.sha256 = Self.normalizedDigest(sha256)
        self.gptkCapable = gptkCapable
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let versionDict = try container.nestedContainer(keyedBy: VersionKeys.self, forKey: .version)
        let major = try versionDict.decode(Int.self, forKey: .major)
        let minor = try versionDict.decode(Int.self, forKey: .minor)
        let patch = try versionDict.decode(Int.self, forKey: .patch)
        version = SemanticVersion(major, minor, patch)
        dxvkVersion = try Self.normalized(container.decodeIfPresent(String.self, forKey: .dxvkVersion))
        dxmtVersion = try Self.normalized(container.decodeIfPresent(String.self, forKey: .dxmtVersion))
        sha256 = try Self.normalizedDigest(container.decodeIfPresent(String.self, forKey: .sha256))
        gptkCapable = try container.decodeIfPresent(Bool.self, forKey: .gptkCapable)
        tag = try Self.normalized(container.decodeIfPresent(String.self, forKey: .tag))
        asset = try Self.normalized(container.decodeIfPresent(String.self, forKey: .asset))
        engines = try container.decodeIfPresent([NightcapWineVersion].self, forKey: .engines)
    }

    /// Collapses an empty string to `nil` so "absent" and "blank" map to the
    /// same state (and never render as a dangling `DXVK:` line).
    private static func normalized(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// Normalizes an advertised SHA-256: trims surrounding whitespace, lowercases,
    /// and requires exactly 64 hex characters. A blank or malformed value (a
    /// publisher typo, truncated paste, placeholder) collapses to `nil` so that
    /// release simply goes unverified, rather than failing every download against
    /// an impossible digest — which would brick installs with a misleading
    /// "download corrupted" error. Integrity here is a corruption tripwire, not
    /// supply-chain trust, so degrading to "unverified" on bad metadata is the
    /// safer failure mode.
    private static func normalizedDigest(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // ASCII-only: `Character.isHexDigit` also matches fullwidth Unicode hex
        // forms, which can never equal CryptoKit's `%02x` output — so without the
        // `isASCII` guard a fullwidth digest would pass here and then fail every
        // download as a mismatch instead of collapsing to nil (skip).
        let isHexDigest = trimmed.count == 64 && trimmed.allSatisfy { $0.isHexDigit && $0.isASCII }
        return isHexDigest ? trimmed : nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var versionDict = container.nestedContainer(keyedBy: VersionKeys.self, forKey: .version)
        try versionDict.encode(version.major, forKey: .major)
        try versionDict.encode(version.minor, forKey: .minor)
        try versionDict.encode(version.patch, forKey: .patch)
        try container.encodeIfPresent(dxvkVersion, forKey: .dxvkVersion)
        try container.encodeIfPresent(dxmtVersion, forKey: .dxmtVersion)
        try container.encodeIfPresent(sha256, forKey: .sha256)
        try container.encodeIfPresent(gptkCapable, forKey: .gptkCapable)
        try container.encodeIfPresent(tag, forKey: .tag)
        try container.encodeIfPresent(asset, forKey: .asset)
        try container.encodeIfPresent(engines, forKey: .engines)
    }

    private enum VersionKeys: String, CodingKey {
        case major, minor, patch
    }
}
