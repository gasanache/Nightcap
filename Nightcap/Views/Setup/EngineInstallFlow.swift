//
//  EngineInstallFlow.swift
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
import SemanticVersion
import SwiftUI

/// Presents setup, either to get started or to switch to a chosen engine.
///
/// Installing a different engine is the same download, hash check and unpack as
/// a first install, so it goes through setup rather than growing a second
/// implementation of all three.
private struct EngineInstallFlowModifier: ViewModifier {
    @Binding var showSetup: Bool

    /// Which engine this run of setup is for. Nil means the manifest default.
    @State private var requestedEngine: SemanticVersion?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSetup) {
                SetupView(
                    showSetup: $showSetup,
                    firstTime: false,
                    targetEngineVersion: requestedEngine
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .installEngineRequested)) { note in
                requestedEngine = note.object as? SemanticVersion
                showSetup = true
            }
            .onChange(of: showSetup) { _, isShowing in
                // The choice belongs to one run of setup, not to the next.
                if !isShowing { requestedEngine = nil }
            }
    }
}

extension View {
    /// Adds the setup sheet and the engine-switch request it answers.
    func engineInstallFlow(showSetup: Binding<Bool>) -> some View {
        modifier(EngineInstallFlowModifier(showSetup: showSetup))
    }
}
