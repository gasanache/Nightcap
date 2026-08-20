//
//  AboutWindowUITests.swift
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

import XCTest

/// Covers the one path into the About window: the App menu.
///
/// Worth a UI test rather than trusting the build, because `CommandGroup`
/// replaces a menu item AppKit would otherwise supply for free — get the scene
/// id or the group wrong and the item is silently dead or missing, which
/// compiles, lints and unit-tests exactly as cleanly as the working version.
@MainActor final class AboutWindowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-NightcapUITestMode", "1"]
        app.launch()
        // Frontmost before interacting: a non-key window makes the menu bar
        // unhittable, the usual source of "element missing" flakiness.
        app.activate()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testAppMenuOpensAboutWindow() throws {
        let appMenu = app.menuBars.menuBarItems["Nightcap"]
        XCTAssertTrue(appMenu.waitForExistence(timeout: 15), "App menu missing")
        appMenu.click()

        let aboutItem = app.menuBars.menuItems["About Nightcap"]
        XCTAssertTrue(aboutItem.waitForExistence(timeout: 5), "About menu item missing")
        aboutItem.click()

        let window = app.windows["About Nightcap"]
        XCTAssertTrue(window.waitForExistence(timeout: 10), "About window did not open")

        // The address is the reason this window exists, and it is shown as the
        // literal URL rather than a word standing in for it. Matched on a
        // descendant's label because the text is the repository button's own
        // label, not a separate static text beside it.
        let repository = window.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "github.com/gasanache/Nightcap"))
            .firstMatch
        XCTAssertTrue(
            repository.waitForExistence(timeout: 5),
            "Repository address missing from the About window"
        )
    }

    /// Asking twice must raise the window that is already open. A `WindowGroup`
    /// here would stack a second copy instead.
    func testAboutWindowIsNotDuplicated() throws {
        for _ in 0 ..< 2 {
            let appMenu = app.menuBars.menuBarItems["Nightcap"]
            XCTAssertTrue(appMenu.waitForExistence(timeout: 15), "App menu missing")
            appMenu.click()
            let aboutItem = app.menuBars.menuItems["About Nightcap"]
            XCTAssertTrue(aboutItem.waitForExistence(timeout: 5), "About menu item missing")
            aboutItem.click()
        }

        let windows = app.windows.matching(NSPredicate(format: "title == %@", "About Nightcap"))
        XCTAssertTrue(
            windows.firstMatch.waitForExistence(timeout: 10),
            "About window did not open"
        )
        XCTAssertEqual(windows.count, 1, "About opened more than one window")
    }
}
