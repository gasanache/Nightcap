//
//  GameConfigApplicator+Overlays.swift
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

// MARK: - Overlay settings

extension GameConfigApplicator {
    /// Applies the FPS counter and Metal HUD toggles.
    ///
    /// The FPS counter has no single mechanism. DXVK draws its own HUD, while
    /// wined3d has no overlay at all and can only report frame rate through
    /// Wine's `fps` debug channel, which lands in the launch log. Both are set
    /// so the counter follows whichever backend ends up active.
    @MainActor
    static func applyOverlaySettings(_ settings: GameConfigVariantSettings, to bottle: Bottle) {
        if let metalHud = settings.metalHud {
            bottle.settings.metalHud = metalHud
        }

        guard let fpsCounter = settings.fpsCounter else { return }
        bottle.settings.dxvkHud = fpsCounter ? .fps : .off
        var env = bottle.settings.environment
        if fpsCounter {
            // Keep the default fixme suppression: a bare "+fps" replaces
            // WINEDEBUG wholesale and unleashes every fixme message, which
            // costs more frames than the counter is worth.
            env["WINEDEBUG"] = "fixme-all,+fps"
        } else {
            env.removeValue(forKey: "WINEDEBUG")
        }
        bottle.settings.environment = env
    }

    /// The preview rows for the overlay toggles, omitting anything already set.
    @MainActor
    static func overlayChanges(
        _ settings: GameConfigVariantSettings,
        bottle: Bottle
    ) -> [ConfigChange] {
        var changes: [ConfigChange] = []

        if let fpsCounter = settings.fpsCounter {
            let current = bottle.settings.dxvkHud != .off
            if fpsCounter != current {
                changes.append(ConfigChange(
                    category: "Graphics",
                    settingName: "FPS Counter",
                    currentValue: current ? "Enabled" : "Disabled",
                    newValue: fpsCounter ? "Enabled" : "Disabled"
                ))
            }
        }

        if let metalHud = settings.metalHud, metalHud != bottle.settings.metalHud {
            changes.append(ConfigChange(
                category: "Graphics",
                settingName: "Metal HUD",
                currentValue: bottle.settings.metalHud ? "Enabled" : "Disabled",
                newValue: metalHud ? "Enabled" : "Disabled"
            ))
        }

        return changes
    }

    /// The preview rows for the variant's environment variables, omitting any
    /// already set to the same value on the bottle.
    @MainActor
    static func environmentChanges(
        _ variant: GameConfigVariant,
        bottle: Bottle
    ) -> [ConfigChange] {
        guard let envVars = variant.environmentVariables, !envVars.isEmpty else { return [] }
        return envVars.sorted { $0.key < $1.key }
            .filter { bottle.settings.environment[$0.key] != $0.value }
            .map { key, value in
                ConfigChange(
                    category: "Environment Variables",
                    settingName: key,
                    currentValue: bottle.settings.environment[key] ?? "(not set)",
                    newValue: value
                )
            }
    }
}
