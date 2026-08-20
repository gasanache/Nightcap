//
//  BottleSetupRecommendationSheet.swift
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

/// The three things a fresh bottle cannot supply for itself.
enum BottleSetupStep: Int, CaseIterable, Identifiable {
    /// Apple's Game Porting Toolkit, which is what makes D3DMetal real.
    case metal
    /// The Visual C++ runtimes almost everything links against.
    case runtimes
    /// Windows libraries Microsoft does not allow to be redistributed.
    case libraries

    var id: Int { rawValue }

    /// A catalog key, not a display string: wrapping a runtime String in
    /// `LocalizedStringKey` looks up text that was never a key, so it silently
    /// falls back to English and localisation never happens.
    var title: LocalizedStringKey {
        switch self {
        case .metal: "setup.bottle.step.metal"
        case .runtimes: "setup.bottle.step.runtimes"
        case .libraries: "setup.bottle.step.libraries"
        }
    }
}

/// Offered once, right after a bottle is created.
///
/// A new prefix is empty, and each of these fails in a way that does not
/// explain itself: a game falls back to OpenGL, a program exits with no window,
/// a viewer reports a missing control. Asking here costs one sheet; finding out
/// later costs a debugging session. Every step is skippable and everything
/// stays available afterwards under Bottle Configuration.
struct BottleSetupRecommendationSheet: View {
    @ObservedObject var bottle: Bottle
    /// Handed the runtimes to install, if any, as this closes. The install runs
    /// after the wizard is gone rather than as a second sheet on top of it:
    /// stacked sheets with different chrome read as a glitch, and the one
    /// underneath still shows its own buttons.
    let onFinish: (DependencyDefinition?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State var step: BottleSetupStep = .metal

    // Step 1
    @State var isBrowsingGPTK: Bool = false
    @State var gptkImporting: Bool = false
    @State var gptkRecord: GPTKStoreRecord?
    @State var gptkError: String?
    @State var engineIsCapable: Bool = false

    // Step 2
    @State var selectedRuntimes: Set<String> = ["vcruntime", "vcrun2013"]

    // Step 3
    @State var isBrowsingLibraries: Bool = false
    @State var librariesSupplied: Bool = false
    @State var libraryError: String?
    @AppStorage("systemLibrarySourceFolder") var sourceFolderPath: String = ""

    var runtimeChoices: [DependencyDefinition] {
        DependencyDefinition.standardDependencies.filter { $0.category == .runtime }
    }

    var body: some View {
        NCSheet(
            title: step.title,
            eyebrow: "setup.bottle.step.eyebrow \(step.rawValue + 1) \(BottleSetupStep.allCases.count)",
            progress: Double(step.rawValue + 1) / Double(BottleSetupStep.allCases.count)
        ) {
            stepContent
        } footer: {
            Text("setup.bottle.footer \(bottle.settings.name)")
                .font(Theme.Typography.detail)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
            NCFooterSpacer()
            // The wizard had no dismissal at all — the only way out was to
            // click through all three steps. Escape now leaves it, and
            // everything here is reachable later in Bottle Configuration.
            Button("button.cancel") {
                onFinish(nil)
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            if step != .metal {
                Button("button.back") { retreat() }
            }
            browseButton
            Button(step == .libraries ? "button.finish" : "button.next") { advance() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .task {
            refreshGPTK()
            refreshLibraries()
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .metal: metalStep
        case .runtimes: runtimesStep
        case .libraries: librariesStep
        }
    }

    /// The optional action for the current step. Only two steps have one, and
    /// neither is required to move on, so it sits beside Next rather than
    /// replacing it.
    @ViewBuilder
    private var browseButton: some View {
        switch step {
        case .metal:
            if gptkRecord == nil {
                Button("setup.bottle.chooseGPTK") { isBrowsingGPTK = true }
            }
        case .runtimes:
            EmptyView()
        case .libraries:
            if !librariesSupplied {
                Button("setup.bottle.chooseFolder") { isBrowsingLibraries = true }
            }
        }
    }

    // MARK: - Navigation

    func advance() {
        guard let next = BottleSetupStep(rawValue: step.rawValue + 1) else {
            // Last step: hand the chosen runtimes back and get out of the way.
            onFinish(selectedRuntimeJob)
            dismiss()
            return
        }
        step = next
    }

    private func retreat() {
        guard let previous = BottleSetupStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }
}
