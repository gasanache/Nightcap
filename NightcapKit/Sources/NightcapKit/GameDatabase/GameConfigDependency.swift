//
//  GameConfigDependency.swift
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

/// Turns a variant's winetricks requirements into a ``DependencyDefinition``.
///
/// Applying a preset used to record ``GameConfigVariant/winetricksVerbs`` in the
/// snapshot and stop there, so a preset that needed a runtime silently did not
/// install it. The apply flow now asks this type what is still missing and hands
/// the result to the same install sheet the bottle's Dependencies section uses.
///
/// ## Usage
///
/// ```swift
/// let installed = await Winetricks.loadInstalledVerbs(for: bottle).verbs
/// if let pending = GameConfigDependency.pendingInstall(
///     entry: entry,
///     variant: variant,
///     installedVerbs: installed
/// ) {
///     // present the install sheet for `pending`
/// }
/// ```
public enum GameConfigDependency {
    /// Returns a definition covering the verbs a variant still needs, or `nil`.
    ///
    /// Verbs listed in `installedVerbs` are dropped, so re-applying a preset whose
    /// components are already in the prefix asks for nothing.
    ///
    /// When the missing verbs exactly match one of
    /// ``DependencyDefinition/standardDependencies``, that definition is returned
    /// so the install UI shows its name, description and time estimate. Otherwise
    /// a definition is synthesised from the entry.
    ///
    /// - Parameters:
    ///   - entry: The game database entry being applied.
    ///   - variant: The variant whose winetricks verbs are required.
    ///   - installedVerbs: Verbs already installed in the target bottle.
    /// - Returns: A definition listing only the missing verbs, or `nil` if none are missing.
    public static func pendingInstall(
        entry: GameDBEntry,
        variant: GameConfigVariant,
        installedVerbs: Set<String>
    ) -> DependencyDefinition? {
        let pending = GameConfigApplicator.pendingWinetricksVerbs(
            variant: variant,
            installedVerbs: installedVerbs
        )
        guard !pending.isEmpty else {
            return nil
        }

        if let standard = DependencyDefinition.standardDependencies.first(
            where: { Set($0.winetricksVerbs) == Set(pending) }
        ) {
            return standard
        }

        return DependencyDefinition(
            id: "gamedb-\(entry.id)",
            displayName: entry.title,
            description: "Components the \(entry.title) configuration needs",
            winetricksVerbs: pending,
            category: .runtime,
            estimatedInstallMinutes: max(2, pending.count * 2)
        )
    }
}
