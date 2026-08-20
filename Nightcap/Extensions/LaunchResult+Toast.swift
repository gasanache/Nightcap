//
//  LaunchResult+Toast.swift
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

extension LaunchResult {
    /// How this launch should be announced.
    ///
    /// The status comes from ``NCStatus`` rather than a toast-only vocabulary:
    /// a launch that failed should look like everything else in the app that
    /// failed. `notificationStyle` and `shouldAutoDismiss` stay in NightcapKit,
    /// where they are tested.
    var toastStatus: NCStatus {
        switch notificationStyle {
        case .success: .ready
        case .info: .available
        case .error: .failed
        }
    }

    var toastMessage: String {
        switch self {
        case let .launchedSuccessfully(name):
            String(localized: "status.launched \(name)")
        case let .launchedInTerminal(name):
            String(localized: "status.launchedTerminal \(name)")
        case let .launchFailed(_, errorDescription):
            String(localized: "status.launchFailed \(errorDescription)")
        }
    }

    /// Announces this result on the app's single toast centre.
    @MainActor
    func announce(on centre: NCToastCenter) {
        centre.show(toastMessage, status: toastStatus, persistent: !shouldAutoDismiss)
    }
}
