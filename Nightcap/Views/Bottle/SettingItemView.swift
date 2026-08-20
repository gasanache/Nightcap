//
//  SettingItemView.swift
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

enum LoadingState: Equatable {
    case loading
    case modifying
    case success
    case failed
}

/// A setting whose current value has to be read off the Wine prefix before the
/// control for it means anything.
///
/// This was ``NCRow`` written earlier and worse — its own 2pt spacing, its own
/// idea of caption type, and nowhere to put a machine value — so it is now a
/// thin wrapper over the real row. What it keeps is the one thing ``NCRow`` has
/// no opinion about: the read may still be in flight, or it may have failed,
/// and the trailing side of the row has to say which.
struct SettingItemView<Content: View>: View {
    let title: String.LocalizationValue
    /// Optional one-line explanation shown beneath the title, so users can make
    /// an informed choice without external docs.
    var description: String.LocalizationValue?
    /// Machine-readable detail read back off the prefix — a registry value, a
    /// build number. A runtime `String`, never a key.
    var machine: String?
    let loadingState: LoadingState
    var onRetry: (() -> Void)?
    @ViewBuilder var content: () -> Content

    @Namespace private var viewId
    @Namespace private var progressViewId

    var body: some View {
        NCRow(
            title: String(localized: title),
            caption: description.map { String(localized: $0) },
            machine: machine
        ) {
            accessory
        }
    }

    /// The reason this wrapper still exists: a spinner while the value is being
    /// read, the control once it is known, and an honest failure with the retry
    /// beside it when the read did not work.
    private var accessory: some View {
        HStack {
            switch loadingState {
            case .loading, .modifying:
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .matchedGeometryEffect(id: progressViewId, in: viewId)
            case .success:
                content()
                    .labelsHidden()
                    // This gate is what keeps every control in the Wine section
                    // inert until its value has actually been read.
                    .disabled(loadingState != .success)
            case .failed:
                failureAccessory
            }
        }
        .animation(.default, value: loadingState)
    }

    /// A failed read said the way the rest of the app says it, rather than as
    /// grey text that could be mistaken for the value itself.
    private var failureAccessory: some View {
        HStack(spacing: Theme.Space.tight) {
            NCStatusBadge(status: .failed, label: "config.notAvailable")
            if let onRetry {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .font(Theme.Typography.rowCaption)
                }
                .buttonStyle(.borderless)
                .help("config.retry")
            }
        }
    }
}
