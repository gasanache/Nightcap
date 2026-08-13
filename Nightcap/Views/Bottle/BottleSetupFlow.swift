//
//  BottleSetupFlow.swift
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

/// Presents the post-creation setup wizard, then whatever it decided to install.
///
/// The two are separate sheets shown one after the other, never stacked. A
/// sheet presented on top of another leaves the first one's buttons visible
/// behind it and the two sets of chrome disagree, which reads as a glitch
/// rather than a flow.
private struct BottleSetupFlowModifier: ViewModifier {
    @ObservedObject var bottleVM: BottleVM

    /// Chosen during the wizard, held until its sheet has actually gone.
    @State private var pending: DependencyDefinition?
    @State private var running: DependencyDefinition?
    @State private var targetBottleURL: URL?

    func body(content: Content) -> some View {
        content
            .sheet(item: $bottleVM.setupPromptBottle, onDismiss: startPendingInstall) { bottle in
                BottleSetupRecommendationSheet(bottle: bottle) { definition in
                    pending = definition
                    targetBottleURL = bottle.url
                }
            }
            .sheet(item: $running) { definition in
                if let bottle = bottleVM.bottles.first(where: { $0.url == targetBottleURL }) {
                    DependencyInstallSheet(definition: definition, bottle: bottle)
                        .frame(minWidth: 500, minHeight: 400)
                }
            }
    }

    private func startPendingInstall() {
        guard let definition = pending else { return }
        pending = nil
        running = definition
    }
}

extension View {
    /// Adds the after-creation setup wizard and its follow-on install.
    func bottleSetupFlow(_ bottleVM: BottleVM) -> some View {
        modifier(BottleSetupFlowModifier(bottleVM: bottleVM))
    }
}
