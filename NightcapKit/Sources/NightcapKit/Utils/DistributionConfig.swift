//
//  DistributionConfig.swift
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

public enum DistributionConfig {
    /// Base URL for the runtime published on this project's own releases.
    ///
    /// Everything the app downloads comes from here. Nothing is fetched from
    /// the upstream projects this fork descends from.
    public static let releasesBaseURL = "https://github.com/gasanache/Nightcap/releases/download"

    /// URL for the runtime version manifest.
    ///
    /// Published under a fixed `dependencies` tag alongside the engines it
    /// describes, so the address never changes when a new runtime ships. The filename stays `WhiskyWineVersion.plist`
    /// because that is what the runtime tarball itself contains.
    public static let versionPlistURL = "\(releasesBaseURL)/dependencies/WhiskyWineVersion.plist"

    /// Constructs the download URL for the Wine runtime.
    /// - Parameter version: The version string (e.g., "3.1.1")
    /// - Returns: The full URL to download Libraries.tar.gz
    public static func librariesURL(version: String) -> String {
        librariesURL(tag: "v\(version)")
    }

    /// Constructs the download URL from a release tag.
    ///
    /// Taking the tag rather than the version is what lets a pre-release be
    /// addressed at all: `v4.0.0-beta.2` cannot be rebuilt from three version
    /// integers, so an engine published under such a tag states it outright.
    ///
    /// - Parameter tag: The release tag, including the leading `v`.
    /// - Returns: The full URL to download Libraries.tar.gz
    public static func librariesURL(tag: String) -> String {
        librariesURL(tag: tag, asset: "Libraries.tar.gz")
    }

    /// Constructs the download URL for a named asset in a release.
    ///
    /// One release can hold every engine, and they cannot all be called
    /// `Libraries.tar.gz`, so the filename is addressed explicitly.
    ///
    /// - Parameters:
    ///   - tag: The release tag, including any leading `v`.
    ///   - asset: The asset filename within that release.
    public static func librariesURL(tag: String, asset: String) -> String {
        "\(releasesBaseURL)/\(tag)/\(asset)"
    }
}
