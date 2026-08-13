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
        Section {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking installed dependencies\u{2026}")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(statuses) { status in
                    dependencyRow(status)
                }
            }
        } header: {
            HStack {
                Label("Dependencies", systemImage: "shippingbox")
                Spacer()
                Button {
                    loadDependencies()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .disabled(isLoading)
                .help("Re-check all dependency statuses")
            }
        }
        .onAppear {
            loadDependencies()
        }
        .sheet(item: $selectedDependency) { definition in
            DependencyInstallSheet(definition: definition, bottle: bottle)
                .frame(minWidth: 500, minHeight: 400)
        }
    }

    // MARK: - Row View

    /// One dependency as a single row: what it is on the left, where it stands
    /// on the right.
    ///
    /// The previous layout stacked a second line underneath carrying "Checked
    /// N ago" on the left and a right-aligned "Details" heading above the verb
    /// list, in a 200pt box. Three competing columns of tertiary text per row,
    /// five rows deep, and the eye had nowhere to rest. The verbs and the check
    /// time are the same kind of information — incidental detail — so they now
    /// share one quiet caption line under the description.
    private func dependencyRow(_ depStatus: DependencyStatus) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(depStatus.definition.displayName)
                    .font(.system(.body, weight: .medium))
                Text(depStatus.definition.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                caption(for: depStatus)
            }

            Spacer(minLength: 8)

            statusBadge(depStatus.status)

            if !isInstalled(depStatus.status) {
                Button("Install") {
                    selectedDependency = depStatus.definition
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
    }

    /// Verbs, freshness and confidence on one line, in reading order.
    private func caption(for depStatus: DependencyStatus) -> some View {
        HStack(spacing: 6) {
            Text(depStatus.definition.winetricksVerbs.joined(separator: ", "))
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)

            if let lastChecked = depStatus.lastChecked {
                Text("·")
                Text("checked ") + Text(lastChecked, style: .relative) + Text(" ago")
            }

            // Only worth saying when the answer is not a fresh direct check.
            if depStatus.confidence == .cached || depStatus.confidence == .heuristic {
                Text("·")
                Text(depStatus.confidence.rawValue)
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }

    // MARK: - Status Badge

    @ViewBuilder
    private func statusBadge(_ status: DependencyInstallStatus) -> some View {
        switch status {
        case .installed:
            Label("Installed", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .notInstalled:
            Label("Not Installed", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        case .partiallyInstalled:
            Label("Partially Installed", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
        case .unknown:
            Label("Unknown", systemImage: "questionmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }

    // MARK: - Helpers

    private func isInstalled(_ status: DependencyInstallStatus) -> Bool {
        if case .installed = status { return true }
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
