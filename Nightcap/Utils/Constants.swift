//
//  Constants.swift
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

enum ViewWidth {
    static let small: Double = 400
    static let medium: Double = 500
    static let large: Double = 600
}

/// Sheet heights, so a sheet picks one rather than inventing it.
///
/// Widths already came from ``ViewWidth``; heights were written per sheet, and
/// eleven sheets each invented their own — 240, 400, 420, 460, 500. These are
/// the rungs those collapse onto.
enum ViewHeight {
    /// One question and its answer. A rename, a DPI value.
    static let compact: Double = 260
    /// A short list, or a form of a few fields.
    static let small: Double = 320
    /// A list to work through, or a step in a sequence.
    static let medium: Double = 460
    /// A transcript, a preview of many changes, a wizard with a rail.
    ///
    /// Deliberately below the height of a modestly sized main window: a sheet
    /// taller than its host is clipped, and the first thing lost is the footer
    /// with the buttons in it. This was 620 and did exactly that.
    static let large: Double = 500
    /// The main window's minimum height, not a sheet.
    static let window: Double = 316
}
