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

    var title: String {
        switch self {
        case .metal: "Metal graphics"
        case .runtimes: "Visual C++ runtimes"
        case .libraries: "Windows libraries"
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
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                stepContent
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
        .frame(width: 540, height: 460)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Step \(step.rawValue + 1) of \(BottleSetupStep.allCases.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(step.title)
                .font(.title2)
                .fontWeight(.bold)
            ProgressView(
                value: Double(step.rawValue + 1),
                total: Double(BottleSetupStep.allCases.count)
            )
            .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            Text("Set \(bottle.settings.name) up now, or do any of it later in Bottle Configuration.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
            Spacer(minLength: 12)
            if step != .metal {
                Button("Back") { retreat() }
            }
            browseButton
            Button(step == .libraries ? "Finish" : "Next") { advance() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(18)
    }

    /// The optional action for the current step. Only two steps have one, and
    /// neither is required to move on, so it sits beside Next rather than
    /// replacing it.
    @ViewBuilder
    private var browseButton: some View {
        switch step {
        case .metal:
            if gptkRecord == nil {
                Button("Choose GPTK\u{2026}") { isBrowsingGPTK = true }
            }
        case .runtimes:
            EmptyView()
        case .libraries:
            if !librariesSupplied {
                Button("Choose Folder\u{2026}") { isBrowsingLibraries = true }
            }
        }
    }

    private func prominent(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
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
