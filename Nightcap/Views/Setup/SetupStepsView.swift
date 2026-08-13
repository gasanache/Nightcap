//
//  SetupStepsView.swift
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

import SwiftUI

/// The stages of first-run setup, shown as a list so the whole sequence is
/// visible from the start.
///
/// Setup used to show one stage at a time as a bare progress bar in an
/// otherwise empty panel: nothing said how many steps there were, which one was
/// running, or what was left. Listing all of them turns a wait of unknown
/// length into a wait with a shape.
enum SetupStep: Int, CaseIterable, Identifiable {
    case download
    case install
    case ready

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .download: "setup.step.download"
        case .install: "setup.step.install"
        case .ready: "setup.step.ready"
        }
    }

    /// What the step is for, so the list explains itself rather than just
    /// naming stages.
    var caption: LocalizedStringKey {
        switch self {
        case .download: "setup.step.download.caption"
        case .install: "setup.step.install.caption"
        case .ready: "setup.step.ready.caption"
        }
    }
}

/// A vertical list of setup stages with the current one highlighted.
struct SetupStepsView: View {
    let current: SetupStep
    /// Trailing text for the active row, e.g. transferred bytes.
    var detail: String?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(SetupStep.allCases) { step in
                row(for: step)
                if step != SetupStep.allCases.last {
                    Divider().padding(.leading, 34)
                }
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
        )
    }

    private func row(for step: SetupStep) -> some View {
        let state = state(for: step)
        return HStack(spacing: 10) {
            indicator(for: state)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(step.title)
                    .font(.system(.subheadline, weight: state == .active ? .semibold : .regular))
                    .foregroundStyle(state == .pending ? .secondary : .primary)
                Text(step.caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            // Only the running step has anything to report.
            if state == .active, let detail {
                Text(detail)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func indicator(for state: StepState) -> some View {
        switch state {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .active:
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        }
    }

    private func state(for step: SetupStep) -> StepState {
        if step.rawValue < current.rawValue {
            .done
        } else if step == current {
            // The last step is an outcome, not work in progress.
            step == .ready ? .done : .active
        } else {
            .pending
        }
    }

    private enum StepState {
        case done
        case active
        case pending
    }
}

/// Shared chrome for the setup stages, so each one is laid out identically.
///
/// The stage views previously padded themselves out with stacked spacers in a
/// fixed 400x200 frame, which left the content floating in an empty panel.
struct SetupPanel<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let step: SetupStep
    var detail: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            SetupStepsView(current: step, detail: detail)

            content
        }
        // The panel grows rather than the caption moving up: the estimate
        // belongs directly under the bar it describes, so the fix for it
        // sitting hard against the edge is room below it, not less above it.
        .padding(.bottom, 22)
        .frame(width: 440, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
