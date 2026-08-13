//
//  GraphicsBackendResolverTests.swift
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
import SemanticVersion
import XCTest

final class GraphicsBackendResolverTests: XCTestCase {
    func testResolvesD3DMetalWhenPayloadInstalled() {
        let runtime = NightcapWineVersion(version: SemanticVersion(3, 1, 1), dxmtVersion: "0.80")

        XCTAssertEqual(
            GraphicsBackendResolver.resolve(runtimeInfo: runtime, d3dMetalInstalled: true),
            .d3dMetal
        )
    }

    func testResolvesDXMTWhenNoD3DMetalButRuntimeBundlesIt() {
        let runtime = NightcapWineVersion(version: SemanticVersion(3, 1, 1), dxmtVersion: "0.80")

        XCTAssertEqual(
            GraphicsBackendResolver.resolve(runtimeInfo: runtime, d3dMetalInstalled: false),
            .dxmt
        )
    }

    func testResolvesDXVKWhenNoD3DMetalAndNoDXMT() {
        // Pre-3.1.0 runtimes bundle DXVK but not DXMT.
        let runtime = NightcapWineVersion(version: SemanticVersion(3, 0, 0))

        XCTAssertEqual(
            GraphicsBackendResolver.resolve(runtimeInfo: runtime, d3dMetalInstalled: false),
            .dxvk
        )
    }

    func testResolvesDXVKWhenRuntimeRecordMissing() {
        XCTAssertEqual(
            GraphicsBackendResolver.resolve(runtimeInfo: nil, d3dMetalInstalled: false),
            .dxvk
        )
    }

    func testNeverResolvesToRecommended() {
        for installed in [true, false] {
            XCTAssertNotEqual(
                GraphicsBackendResolver.resolve(runtimeInfo: nil, d3dMetalInstalled: installed),
                .recommended
            )
        }
    }
}
