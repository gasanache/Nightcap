//
//  AboutInfo.swift
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
import NightcapKit

/// The facts the About window states, in one place.
///
/// Addresses are `String` rather than `URL` because a `URL` literal cannot be
/// written without force-unwrapping; callers convert and handle the `nil` the
/// same way the Help menu already does.
enum AboutInfo {
    // MARK: - Identity

    static var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Nightcap"
    }

    static var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    /// `1.0.1 (10001)`. The word "Version" is left off deliberately: the line
    /// sits directly under the app's name, where nothing else it could be, and
    /// leaving it out keeps the whole line a machine value in the monospaced
    /// role rather than prose and digits sharing a font.
    static var versionLine: String {
        buildNumber.isEmpty ? shortVersion : "\(shortVersion) (\(buildNumber))"
    }

    // MARK: - Addresses

    static let repository = "https://github.com/gasanache/Nightcap"
    static let issues = "\(repository)/issues"
    static let license = "\(repository)/blob/main/LICENSE"

    /// The repository address as it is shown to the reader. Derived rather than
    /// written twice, so the label cannot drift from the link it opens.
    static var repositoryDisplay: String {
        guard let host = repository.range(of: "://") else { return repository }
        return String(repository[host.upperBound...])
    }

    // MARK: - Runtime

    /// `SemanticVersion` has no display form of its own, and the diagnostics
    /// exporter assembles the same three fields by hand.
    static func runtimeVersion(_ runtime: NightcapWineVersion) -> String {
        "\(runtime.version.major).\(runtime.version.minor).\(runtime.version.patch)"
    }

    /// Everything the window shows, as plain text for a bug report.
    ///
    /// Deliberately not localised: it is written to be pasted into an issue,
    /// where English is what the reader of that issue needs.
    static func versionReport(_ runtime: NightcapWineVersion?) -> String {
        var lines = ["\(appName) \(versionLine)"]
        if let runtime {
            lines.append("Wine Libraries \(runtimeVersion(runtime))")
            if let dxvk = runtime.dxvkVersion {
                lines.append("DXVK \(dxvk)")
            }
            if let dxmt = runtime.dxmtVersion {
                lines.append("DXMT \(dxmt)")
            }
        } else {
            lines.append("Wine Libraries not installed")
        }
        lines.append("macOS \(MacOSVersion.current.description)")
        lines.append(HostArchitecture.isAppleSilicon ? "Apple Silicon (arm64)" : "Intel (x86_64)")
        return lines.joined(separator: "\n")
    }
}
