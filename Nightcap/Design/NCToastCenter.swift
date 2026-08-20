//
//  NCToastCenter.swift
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

/// The one place a passing message appears.
///
/// Thirteen files owned or threaded a toast of their own: seven held their own
/// `@State`, six more took one as a `@Binding` so a child could reach a
/// parent's. Several of those overlays nested inside each other on the same
/// window at the same bottom edge, so a device alert, a zombie-cleanup notice
/// and a launch failure could render stacked on top of one another.
///
/// One object in the environment, one overlay, one at a time.
@MainActor
@Observable
final class NCToastCenter {
    private(set) var current: Toast?

    /// A message and how it should be read, with no styling vocabulary of its
    /// own — ``NCStatus`` already says what green, red and orange mean
    /// everywhere else in the app.
    struct Toast: Equatable, Identifiable {
        let id = UUID()
        let message: String
        let status: NCStatus
        /// A failure the user may want to act on stays until dismissed; a
        /// success announces itself and goes.
        let persistent: Bool

        static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
    }

    private var dismissTask: Task<Void, Never>?
    private static let visibleFor: Duration = .seconds(3)

    /// Shows a message, replacing whatever was on screen.
    ///
    /// - Parameter message: already-resolved text. Most of these interpolate a
    ///   runtime value, so callers pass `String(localized:)` themselves for the
    ///   fixed ones rather than this taking a key it could not interpolate.
    func show(_ message: String, status: NCStatus, persistent: Bool = false) {
        dismissTask?.cancel()
        current = Toast(message: message, status: status, persistent: persistent)
        guard !persistent else { return }
        let shown = current
        dismissTask = Task {
            try? await Task.sleep(for: Self.visibleFor)
            guard !Task.isCancelled, current == shown else { return }
            dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        current = nil
    }
}

/// The toast itself.
private struct NCToastView: View {
    let toast: NCToastCenter.Toast
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.Space.snug) {
            Image(systemName: toast.status.symbol)
                .foregroundStyle(toast.status.tint)
            Text(toast.message)
                // Three lines rather than two: a launch failure carries a path,
                // and truncating it removes the only useful part.
                .lineLimit(toast.persistent ? 3 : 2)
                .font(Theme.Typography.rowCaption)
            // A real Button. This was an Image that looked like one while the
            // whole toast carried the tap gesture, so the affordance was a lie.
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("accessibility.toast.dismiss")
        }
        .padding(.horizontal, Theme.Space.card)
        .padding(.vertical, Theme.Space.row)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(toast.message)
    }
}

private struct NCToastLayer: ViewModifier {
    @Environment(NCToastCenter.self) private var centre

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = centre.current {
                    NCToastView(toast: toast) { centre.dismiss() }
                        // The clearance belongs to the toast, not the window.
                        // Applying it as a safe-area inset on the content
                        // permanently shrank every screen by that much, whether
                        // or not a toast was showing.
                        .padding(.bottom, Theme.Space.card)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: centre.current)
    }
}

extension View {
    /// Applied exactly once, on the root content view.
    func ncToastLayer() -> some View {
        modifier(NCToastLayer())
    }
}
