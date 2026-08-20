//
//  AppAppearance.swift
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

import AppKit
import SwiftUI

/// Light, dark, or whatever the Mac is doing.
///
/// Set on `NSApplication` rather than through SwiftUI's `preferredColorScheme`:
/// that modifier only reaches the view tree it is applied to, which would leave
/// the parts AppKit draws for us — window frames, menus, the open and save
/// panels — following the system while the app's own views did not.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    /// Where the choice is stored. Named here so the app delegate and the
    /// settings picker cannot disagree about the key.
    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .system: "settings.appearance.system"
        case .light: "settings.appearance.light"
        case .dark: "settings.appearance.dark"
        }
    }

    /// `nil` is not a missing value — it is how AppKit spells "follow the
    /// system", which is why that is also this setting's default.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// The stored choice, or `.system` when nothing has been chosen. Reading
    /// through this rather than `UserDefaults.string` directly keeps an
    /// unrecognised value — a downgrade, a hand-edited plist — landing on the
    /// default instead of leaving the app unstyled.
    static var stored: AppAppearance {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return AppAppearance(rawValue: raw) ?? .system
    }

    @MainActor
    func apply() {
        NSApplication.shared.appearance = nsAppearance
    }

    /// Applies the stored choice. Called once at launch, before any window is
    /// on screen, so the first frame is already in the right appearance.
    @MainActor
    static func applyStored() {
        stored.apply()
    }
}
