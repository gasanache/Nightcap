//
//  NCLogPanel.swift
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

/// A transcript, read rather than skimmed.
///
/// Streamed output appeared in three places wearing three different fonts, and
/// the dependency installer kept its only copy in view state, so closing the
/// sheet destroyed the evidence. This is the one place the app renders lines of
/// machine output.
struct NCLogPanel<Toolbar: View>: View {
    let lines: [String]
    /// Follows the tail. Off, the panel leaves the scroll position alone —
    /// yanking a finished log back to the bottom while someone is reading it is
    /// worse than not following at all.
    var isLive: Bool = false
    var emptyMessage: LocalizedStringKey?
    @ViewBuilder var toolbar: Toolbar

    /// A 600-second winetricks install can emit far more than a lazy stack will
    /// scroll through comfortably, so only the tail is rendered.
    private static var renderLimit: Int { 2_000 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var visible: [String] {
        lines.count > Self.renderLimit ? Array(lines.suffix(Self.renderLimit)) : lines
    }

    private var hidden: Int {
        max(0, lines.count - Self.renderLimit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            header
            if lines.isEmpty {
                NCEmptyState(
                    systemImage: "text.alignleft",
                    title: emptyMessage ?? "log.empty"
                )
            } else {
                transcript
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if isLive || !(toolbar is EmptyView) {
            HStack(spacing: Theme.Space.snug) {
                if isLive {
                    liveMarker
                }
                Spacer(minLength: Theme.Space.snug)
                toolbar
            }
        }
    }

    private var liveMarker: some View {
        HStack(spacing: Theme.Space.tight) {
            Circle()
                .fill(NCStatus.running.tint)
                .frame(width: Theme.Space.snug, height: Theme.Space.snug)
                .opacity(pulse ? 0.3 : 1)
            Text("log.live")
                .font(Theme.Typography.detail)
                .foregroundStyle(.secondary)
        }
        // Driven by `isLive` rather than by appearance: an install that
        // finishes and starts again reuses the same view, so an onAppear pulse
        // would never restart.
        .onChange(of: isLive, initial: true) { _, live in
            guard live, !reduceMotion else {
                withAnimation(.default) { pulse = false }
                return
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if hidden > 0 {
                        Text("log.truncated \(hidden)")
                            .font(Theme.Typography.detail)
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, Theme.Space.tight)
                    }
                    // Identity is the line's position in the WHOLE log, not in
                    // the visible window. Keyed on the window offset, every row
                    // changes identity each time a line arrives past the cap,
                    // so the entire list rebuilds on every append.
                    ForEach(Array(visible.enumerated()), id: \.offset) { offset, line in
                        let absolute = hidden + offset
                        Text(line)
                            .font(Theme.Typography.machine)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(absolute)
                    }
                }
                .padding(Theme.Space.snug)
            }
            .background(.quaternary.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .onChange(of: lines.count) {
                // Scroll to the same absolute id the rows are keyed on.
                guard isLive, !visible.isEmpty else { return }
                proxy.scrollTo(hidden + visible.count - 1, anchor: .bottom)
            }
        }
    }
}

extension NCLogPanel where Toolbar == EmptyView {
    init(lines: [String], isLive: Bool = false, emptyMessage: LocalizedStringKey? = nil) {
        self.init(lines: lines, isLive: isLive, emptyMessage: emptyMessage, toolbar: { EmptyView() })
    }
}
