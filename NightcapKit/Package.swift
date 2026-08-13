// swift-tools-version: 6.0
//
//  Package.swift
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

import PackageDescription

let package = Package(
    name: "NightcapKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "NightcapKit",
            targets: ["NightcapKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftPackageIndex/SemanticVersion.git", from: "0.5.1"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "NightcapKit",
            dependencies: ["SemanticVersion"],
            resources: [
                .process("Diagnostics/Resources/"),
                .process("GameDatabase/Resources/"),
                .process("Troubleshooting/Resources/")
            ]
        ),
        .testTarget(
            name: "NightcapKitTests",
            dependencies: ["NightcapKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
