//
//  SetupView.swift
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

enum SetupStage {
    case rosetta
    case nightcapWineDownload
    case nightcapWineInstall
}

struct SetupView: View {
    @State private var path: [SetupStage] = []
    @State var tarLocation: URL = .init(fileURLWithPath: "")
    @State private var nightcapWineDiagnostics = NightcapWineSetupDiagnostics()
    @Binding var showSetup: Bool
    var firstTime: Bool = true
    /// Install this engine rather than the default, when setup was opened to
    /// switch engines instead of to get started.
    var targetEngineVersion: SemanticVersion?

    var body: some View {
        VStack {
            NavigationStack(path: $path) {
                WelcomeView(path: $path, showSetup: $showSetup, firstTime: firstTime)
                    .navigationBarBackButtonHidden(true)
                    .navigationDestination(for: SetupStage.self) { stage in
                        switch stage {
                        case .rosetta:
                            RosettaView(path: $path, showSetup: $showSetup)
                        case .nightcapWineDownload:
                            NightcapWineDownloadView(
                                tarLocation: $tarLocation,
                                path: $path,
                                showSetup: $showSetup,
                                diagnostics: $nightcapWineDiagnostics,
                                targetEngineVersion: targetEngineVersion
                            )
                        case .nightcapWineInstall:
                            NightcapWineInstallView(
                                tarLocation: $tarLocation,
                                path: $path,
                                showSetup: $showSetup,
                                diagnostics: $nightcapWineDiagnostics
                            )
                        }
                    }
            }
        }
        .padding()
        .interactiveDismissDisabled()
        .onAppear {
            // A re-entry into setup has nothing to say on the welcome screen:
            // either the runtime is missing, or a particular engine was asked
            // for. Without that second case, choosing an engine while one is
            // already installed lands on "everything is ready" and the engine
            // that was asked for never downloads.
            guard !firstTime else { return }
            if targetEngineVersion != nil || !NightcapWineInstaller.isNightcapWineInstalled() {
                path = [.nightcapWineDownload]
            }
        }
    }
}
