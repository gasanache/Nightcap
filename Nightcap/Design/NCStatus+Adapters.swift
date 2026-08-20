//
//  NCStatus+Adapters.swift
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

import NightcapKit
import SwiftUI

/// Where the app's own vocabularies meet the one the user sees.
///
/// ``NCStatus`` deliberately knows nothing about NightcapKit — it lives in
/// ``DesignSystem`` and stays importable from anywhere. These adapters are the
/// single place a domain result becomes a colour and a glyph.
///
/// Only the mappings with live call sites are here. Adapters for
/// `CompatibilityRating`, `CheckOutcome`, `FixResult`, `AudioStatus`,
/// `ConfidenceTier` and `CrashCategory` were written ahead of the screens that
/// would use them and then had none, so they were deleted rather than shipped
/// unused; they belong in the same change as the conversion that needs them.
extension NCStatus {
    /// Whether a bottle's dependency is present.
    ///
    /// `partiallyInstalled` is `.missing` and not `.failed`: something is
    /// absent and the user can install it. Nothing went wrong.
    init(_ status: DependencyInstallStatus) {
        switch status {
        case .installed: self = .ready
        case .notInstalled, .partiallyInstalled: self = .missing
        case .unknown: self = .unknown
        }
    }

    /// A process the app launched.
    ///
    /// A nil exit code with nothing running is `.unknown` rather than a
    /// success: the app simply did not see how it ended.
    init(exitCode: Int32?, isRunning: Bool) {
        if isRunning {
            self = .running
        } else if let exitCode {
            self = exitCode == 0 ? .ready : .failed
        } else {
            self = .unknown
        }
    }
}
