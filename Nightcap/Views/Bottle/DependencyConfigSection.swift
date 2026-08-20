//
//  DependencyConfigSection.swift
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

/// Dependencies section for the bottle Config view.
///
/// Shows ``DependencyDefinition/standardDependencies`` (Visual C++ runtimes,
/// .NET Framework, DirectX, DirectX Audio) with installation status, confidence
/// indicator, last-checked timestamp, and Install action. Manages its own state
/// and presents ``DependencyInstallSheet`` via a sheet binding.
struct DependencyConfigSection: View {
    @ObservedObject var bottle: Bottle

    @State private var statuses: [DependencyStatus] = []
    @State private var isLoading: Bool = true
    @State private var selectedDependency: DependencyDefinition?

    var body: some View {
        NCSection(
            title: "dependency.section",
            systemImage: "shippingbox",
            accessory: { headerAccessory },
            content: { sectionContent }
        )
        .onAppear {
            loadDependencies()
        }
        // Keyed on the bottle: switching bottles in the sidebar reuses this
        // view, so `onAppear` alone would leave the previous bottle's answers
        // on screen.
        .onChange(of: bottle.url) {
            loadDependencies()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dependenciesChanged)) { note in
            guard note.object as? URL == bottle.url else { return }
            loadDependencies()
        }
        // Winetricks can also be run from the sheet that shells out to
        // Terminal, and the app has no way to know when that finished. Coming
        // back to Nightcap is the moment to look again. Cheap when nothing
        // changed: the verb cache keys off the winetricks log's size and
        // modification date, so an unchanged prefix is a cache hit.
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in
            loadDependencies()
        }
        .sheet(item: $selectedDependency, onDismiss: loadDependencies) { definition in
            DependencyInstallSheet(definition: definition, bottle: bottle)
        }
    }

    // MARK: - Header

    /// The refresh control, and — while a check is running — the fact that one
    /// is running.
    ///
    /// The spinner used to stand where the rows were, so every refresh emptied
    /// the section and the whole page reflowed under the cursor. The rows stay
    /// put now; only this accessory changes.
    private var headerAccessory: some View {
        HStack(spacing: Theme.Space.snug) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(Text("dependency.checking"))
            }
            Button {
                loadDependencies()
            } label: {
                Label("dependency.refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(isLoading)
            .help("dependency.refresh.help")
        }
    }

    // MARK: - Content

    /// Only the very first check has no rows to keep, so only the first check
    /// says anything in the body.
    @ViewBuilder
    private var sectionContent: some View {
        if statuses.isEmpty {
            if isLoading {
                NCNotice(status: .running, message: String(localized: "dependency.checking"))
            } else {
                NCEmptyState(
                    systemImage: "shippingbox",
                    title: "dependency.empty.title",
                    message: "dependency.empty.message"
                ) {
                    Button("dependency.refresh") {
                        loadDependencies()
                    }
                }
            }
        } else {
            ForEach(statuses) { status in
                dependencyRow(status)
            }
        }
    }

    // MARK: - Row View

    /// One dependency as a single row: what it is on the left, where it stands
    /// on the right.
    ///
    /// This was `NCRow` rebuilt by hand, with its own spacings and its own
    /// four-colour status vocabulary — green, red, yellow, grey — while the
    /// next section down the same page painted "not present" orange. The badge
    /// and the row are the shared ones now, so the two agree.
    private func dependencyRow(_ depStatus: DependencyStatus) -> some View {
        NCRow(
            title: depStatus.definition.displayName,
            caption: caption(for: depStatus),
            machine: depStatus.definition.winetricksVerbs.joined(separator: ", ")
        ) {
            HStack(spacing: Theme.Space.snug) {
                NCStatusBadge(
                    status: NCStatus(depStatus.status),
                    label: label(for: depStatus.status)
                )

                if !isInstalled(depStatus.status) {
                    Button("dependency.install") {
                        selectedDependency = depStatus.definition
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    /// What the dependency is, how fresh the answer is, and how it was reached.
    ///
    /// The freshness used to be three `Text` values glued together with `+` —
    /// "checked ", the date, " ago" — a sentence no translator could reorder.
    /// It is one format key taking the relative date as its argument now.
    private func caption(for depStatus: DependencyStatus) -> String {
        var parts = [depStatus.definition.description]

        if let lastChecked = depStatus.lastChecked {
            let relative = lastChecked.formatted(.relative(presentation: .named))
            parts.append(String(localized: "dependency.lastChecked \(relative)"))
        }

        // Only worth saying when the answer is not a fresh direct check.
        if depStatus.confidence == .cached || depStatus.confidence == .heuristic {
            parts.append(depStatus.confidence.rawValue)
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - Helpers

    private func label(for status: DependencyInstallStatus) -> LocalizedStringKey {
        switch status {
        case .installed: "dependency.installed"
        case .notInstalled: "dependency.notInstalled"
        case .partiallyInstalled: "dependency.partial"
        case .unknown: "dependency.unknown"
        }
    }

    private func isInstalled(_ status: DependencyInstallStatus) -> Bool {
        if case .installed = status {
            return true
        }
        return false
    }

    private func loadDependencies() {
        isLoading = true
        Task {
            let results = await DependencyManager.checkDependencies(for: bottle)
            await MainActor.run {
                statuses = results
                isLoading = false
            }
        }
    }
}
