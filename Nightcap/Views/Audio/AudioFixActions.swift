//
//  AudioFixActions.swift
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

/// The audio fixes, applied for real.
///
/// Two surfaces offer audio fixes: the findings list on the Config page and
/// the troubleshooting wizard. Only the first ever applied anything — the
/// wizard recorded the action id and moved to "Did it work?", so the driver it
/// promised to set stayed unset and the resolved screen listed the phantom
/// under "Changes applied". This is the one mapping both call.
enum AudioFixActions {
    @MainActor
    static func apply(_ actionId: String, to bottle: Bottle) async {
        switch actionId {
        case "check-audio-driver", "set-coreaudio-driver":
            bottle.settings.audioDriver = .coreaudio
            try? await Wine.setAudioDriver(bottle: bottle, driver: .coreaudio)
        case "set-stable-latency":
            bottle.settings.audioLatencyPreset = .stable
            try? await Wine.setDirectSoundBuffer(
                bottle: bottle,
                helBuflen: AudioLatencyPreset.stable.helBuflenValue
            )
        case "reset-audio-state":
            try? await Wine.resetAudioState(bottle: bottle)
        default:
            break
        }
    }

    /// One place that knows which probes a wizard needs, so the two screens
    /// that open it cannot drift apart.
    @MainActor
    static func makeEngine(bottle: Bottle, monitor: AudioDeviceMonitor) -> AudioTroubleshootingEngine {
        let probes: [any AudioProbe] = [
            CoreAudioDeviceProbe(monitor: monitor),
            WineRegistryAudioProbe(bottle: bottle),
            WineAudioTestProbe(
                bottle: bottle,
                testExeURL: Bundle.main.url(forResource: "NightcapAudioTest", withExtension: "exe")
            )
        ]
        return AudioTroubleshootingEngine(probes: probes)
    }
}
