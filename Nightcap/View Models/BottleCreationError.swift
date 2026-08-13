//
//  BottleCreationError.swift
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
import os.log
import SemanticVersion

// MARK: - Bottle Creation Errors

enum BottleCreationError: LocalizedError, Equatable {
    case directoryCreationFailed
    case metadataCreationFailed
    case wineVersionChangeFailed
    case persistenceSaveFailed
    /// The Wine runtime (NightcapWine) is not installed, so the prefix can't be
    /// initialized. Surfaced with a "Run Setup" action in the failure alert.
    case runtimeMissing
    /// The chosen location failed pre-flight validation. Carries the already
    /// localized, user-facing message (built at the throw site) since the alert
    /// displays `errorDescription` verbatim.
    case locationUnsuitable(message: String)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed:
            String(localized: "bottle.creation.error.directoryCreationFailed")
        case .metadataCreationFailed:
            String(localized: "bottle.creation.error.metadataCreationFailed")
        case .wineVersionChangeFailed:
            String(localized: "bottle.creation.error.wineVersionChangeFailed")
        case .persistenceSaveFailed:
            String(localized: "bottle.creation.error.persistenceSaveFailed")
        case .runtimeMissing:
            String(localized: "bottle.creation.error.runtimeMissing")
        case let .locationUnsuitable(message):
            message
        }
    }
}

/// Why a bottle location was refused, phrased for the user, or `nil` when it is
/// usable. Shared so the creation sheet and the failure alert cannot drift.
func bottleLocationRefusal(_ result: BottleLocationValidation.ValidationResult) -> String? {
    switch result {
    case .valid:
        nil
    case let .notWritable(path):
        String(format: String(localized: "bottle.creation.preflight.notWritable"), path)
    case let .accessDenied(path):
        String(format: String(localized: "bottle.creation.preflight.accessDenied"), path)
    case let .insufficientSpace(available, required):
        String(
            format: String(localized: "bottle.creation.preflight.insufficientSpace"),
            ByteCountFormatter.string(fromByteCount: available, countStyle: .file),
            ByteCountFormatter.string(fromByteCount: required, countStyle: .file)
        )
    }
}
