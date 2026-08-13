//
//  EngineManifestTests.swift
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
import SemanticVersion
import XCTest

/// Covers a manifest that offers more than one Wine engine.
///
/// The engines are a trade, not a progression: the default is newer Wine and
/// the GPTK-capable build is older Wine that can execute D3DMetal. The two
/// things worth pinning are that an older app still reads such a manifest
/// exactly as it did before, and that a pre-release tag survives — it cannot be
/// rebuilt from three version integers, which is what blocked this before.
final class EngineManifestTests: XCTestCase {
    private func decode(_ xml: String) throws -> NightcapWineVersion {
        try PropertyListDecoder().decode(NightcapWineVersion.self, from: Data(xml.utf8))
    }

    private func manifest(withEngines: Bool) -> String {
        let engines = """
            <key>engines</key>
            <array>
                <dict>
                    <key>gptkCapable</key><true/>
                    <key>tag</key><string>v4.0.0-beta.2</string>
                    <key>dxmtVersion</key><string>0.80</string>
                    <key>version</key>
                    <dict>
                        <key>major</key><integer>4</integer>
                        <key>minor</key><integer>0</integer>
                        <key>patch</key><integer>0</integer>
                    </dict>
                </dict>
            </array>
        """
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>dxvkVersion</key><string>1.10.3</string>
            <key>dxmtVersion</key><string>0.80</string>
            <key>version</key>
            <dict>
                <key>major</key><integer>3</integer>
                <key>minor</key><integer>1</integer>
                <key>patch</key><integer>1</integer>
            </dict>
            \(withEngines ? engines : "")
        </dict>
        </plist>
        """
    }

    // MARK: - Backward compatibility

    /// The root must keep meaning what it always meant, so a build that knows
    /// nothing about `engines` resolves the same runtime it resolved before.
    func testRootStillDescribesTheDefaultEngine() throws {
        let decoded = try decode(manifest(withEngines: true))
        XCTAssertEqual(decoded.version, SemanticVersion(3, 1, 1))
        XCTAssertEqual(decoded.releaseTag, "v3.1.1")
        XCTAssertNil(decoded.gptkCapable)
    }

    func testManifestWithoutEnginesStillDecodes() throws {
        let decoded = try decode(manifest(withEngines: false))
        XCTAssertNil(decoded.engines)
        XCTAssertEqual(decoded.availableEngines.count, 1)
        XCTAssertEqual(decoded.availableEngines.first?.releaseTag, "v3.1.1")
    }

    // MARK: - The second engine

    func testSecondEngineIsListed() throws {
        let decoded = try decode(manifest(withEngines: true))
        XCTAssertEqual(decoded.availableEngines.count, 2)

        let gptk = try XCTUnwrap(decoded.availableEngines.last)
        XCTAssertEqual(gptk.version, SemanticVersion(4, 0, 0))
        XCTAssertEqual(gptk.gptkCapable, true)
    }

    /// The whole point: `v4.0.0-beta.2` cannot be derived from 4.0.0, so a
    /// stated tag has to win over the conventional one.
    func testPreReleaseTagSurvives() throws {
        let decoded = try decode(manifest(withEngines: true))
        let gptk = try XCTUnwrap(decoded.availableEngines.last)

        XCTAssertEqual(gptk.releaseTag, "v4.0.0-beta.2")
        XCTAssertEqual(
            DistributionConfig.librariesURL(tag: gptk.releaseTag),
            "\(DistributionConfig.releasesBaseURL)/v4.0.0-beta.2/Libraries.tar.gz"
        )
    }

    /// An engine without a tag falls back to the conventional one, so ordinary
    /// releases need no extra field.
    func testMissingTagFallsBackToTheVersion() {
        let engine = NightcapWineVersion(version: SemanticVersion(3, 1, 1))
        XCTAssertEqual(engine.releaseTag, "v3.1.1")
        XCTAssertEqual(
            DistributionConfig.librariesURL(tag: engine.releaseTag),
            DistributionConfig.librariesURL(version: "3.1.1")
        )
    }

    /// The root entry must not carry the list with it, or a chosen engine would
    /// drag every other engine along as a nested copy.
    func testRootEntryDoesNotRepeatTheList() throws {
        let decoded = try decode(manifest(withEngines: true))
        XCTAssertNil(decoded.availableEngines.first?.engines)
    }

    // MARK: - Round trip

    func testEnginesSurviveEncoding() throws {
        let decoded = try decode(manifest(withEngines: true))
        let data = try PropertyListEncoder().encode(decoded)
        let round = try PropertyListDecoder().decode(NightcapWineVersion.self, from: data)

        XCTAssertEqual(round.availableEngines.count, 2)
        XCTAssertEqual(round.availableEngines.last?.releaseTag, "v4.0.0-beta.2")
        XCTAssertEqual(round.availableEngines.last?.gptkCapable, true)
    }
}
