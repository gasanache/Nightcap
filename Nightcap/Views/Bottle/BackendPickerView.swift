//
//  BackendPickerView.swift
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

struct BackendPickerView: View {
    @Binding var selection: GraphicsBackend
    let resolvedBackend: GraphicsBackend
    /// Whether a backend can be offered on this machine. Defaults to all-true;
    /// production callers gate payload-dependent backends (DXMT) on the
    /// installed runtime.
    var isBackendAvailable: (GraphicsBackend) -> Bool = { _ in true }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            LazyVGrid(columns: columns, spacing: Theme.Space.row) {
                ForEach(GraphicsBackend.allCases, id: \.self) { backend in
                    BackendCard(
                        backend: backend,
                        isSelected: selection == backend,
                        isAvailable: isBackendAvailable(backend),
                        resolvedBackend: backend == .recommended ? resolvedBackend : nil
                    ) {
                        selection = backend
                    }
                }
            }

            // Helper text below grid
            helperText
        }
    }

    // MARK: - Helper Text

    @ViewBuilder
    private var helperText: some View {
        if selection == .recommended {
            Text("config.graphics.helperCurrently \(resolvedBackend.displayName)")
                .font(Theme.Typography.rowCaption)
                .foregroundStyle(.secondary)
        } else {
            Text("config.graphics.helperNextLaunch")
                .font(Theme.Typography.rowCaption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - BackendCard

private struct BackendCard: View {
    /// The selected border `NCCard` draws. `NCOptionCard` does not forward
    /// `NCCard`'s `isSelected`, so the picker restates the one value it needs
    /// rather than restating the whole card.
    private static let selectedBorder: CGFloat = 2
    /// How far a capability tag's colour lifts off the card behind it.
    private static let tagFillOpacity: Double = 0.15

    let backend: GraphicsBackend
    let isSelected: Bool
    let isAvailable: Bool
    let resolvedBackend: GraphicsBackend?
    let action: () -> Void

    @State private var showRationale: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            NCOptionCard(
                title: titleKey,
                detail: isAvailable ? summaryKey : unavailableReasonKey,
                systemImage: iconName,
                isAvailable: isAvailable,
                action: action
            ) {
                accessory
            }
            .overlay {
                selectionBorder
            }

            if backend == .recommended, isSelected, let resolved = resolvedBackend {
                Text("config.graphics.currentlyUsing \(resolved.displayName)")
                    .font(Theme.Typography.detail)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Selection is a heavier tinted border, the treatment `NCCard` settles on.
    /// What was here before — a solid accent fill with forced white text — was
    /// the app's only instance of it and unreadable in dark mode.
    @ViewBuilder
    private var selectionBorder: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(.tint, lineWidth: Self.selectedBorder)
        }
    }

    /// The capability tag and — for Recommended only — the rationale popover,
    /// on the card's trailing edge where the old top row already put them.
    private var accessory: some View {
        HStack(spacing: Theme.Space.tight) {
            if let tag = tagLabel {
                capabilityTag(tag)
            }
            if backend == .recommended {
                rationaleButton
            }
        }
    }

    /// Deliberately not an `NCStatusBadge`. These four tags say what a backend
    /// is *like* — fast, compatible, experimental, a fallback — which is a
    /// different axis from whether a component is present or working. They
    /// borrow `NCStatus`'s green, blue and orange, and that collision is worth
    /// resolving, but not by quietly repainting editorial colour here.
    private func capabilityTag(_ tag: (text: String, color: Color)) -> some View {
        Text(tag.text)
            .font(Theme.Typography.detail)
            .fontWeight(.medium)
            .padding(.horizontal, Theme.Space.snug)
            .padding(.vertical, Theme.Space.tight)
            .background(tag.color.opacity(Self.tagFillOpacity), in: Capsule())
            .foregroundStyle(tag.color)
    }

    private var rationaleButton: some View {
        Button {
            showRationale.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(Theme.Typography.rowCaption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showRationale) {
            Text(GraphicsBackendResolver.rationale())
                .font(Theme.Typography.rowCaption)
                .padding(Theme.Space.card)
                .frame(maxWidth: 240)
        }
    }

    // MARK: - Labels

    /// `NCOptionCard` labels a choice with catalogue keys, while
    /// `GraphicsBackend.displayName` and `.summary` hand back already-resolved
    /// `String`s. The card names the same entries the backend does rather than
    /// looking a runtime value up as a key.
    private var titleKey: LocalizedStringKey {
        switch backend {
        case .recommended:
            "config.graphics.backend.recommended"
        case .d3dMetal:
            "config.graphics.backend.d3dMetal.name"
        case .dxvk:
            "config.graphics.backend.dxvk.name"
        case .dxmt:
            "config.graphics.backend.dxmt.name"
        case .wined3d:
            "config.graphics.backend.wined3d.name"
        }
    }

    private var summaryKey: LocalizedStringKey {
        switch backend {
        case .recommended:
            "config.graphics.backend.recommended.summary"
        case .d3dMetal:
            "config.graphics.backend.d3dMetal.summary"
        case .dxvk:
            "config.graphics.backend.dxvk.summary"
        case .dxmt:
            "config.graphics.backend.dxmt.summary"
        case .wined3d:
            "config.graphics.backend.wined3d.summary"
        }
    }

    // MARK: - Unavailability

    /// Only payload-dependent backends (DXMT, D3DMetal) can be unavailable;
    /// each explains what the installed engine is missing (issue #146).
    private var unavailableReasonKey: LocalizedStringKey {
        backend == .d3dMetal
            ? "config.graphics.backend.d3dMetal.unavailable"
            : "config.graphics.backend.dxmt.unavailable"
    }

    // MARK: - Icon

    private var iconName: String {
        switch backend {
        case .recommended:
            "sparkles"
        case .d3dMetal:
            "display"
        case .dxvk:
            "arrow.triangle.2.circlepath"
        case .dxmt:
            "cube.transparent"
        case .wined3d:
            "cup.and.saucer"
        }
    }

    // MARK: - Tag

    private var tagLabel: (text: String, color: Color)? {
        switch backend {
        case .recommended:
            nil
        case .d3dMetal:
            (String(localized: "config.graphics.tag.fast"), .green)
        case .dxvk:
            (String(localized: "config.graphics.tag.compatible"), .blue)
        case .dxmt:
            (String(localized: "config.graphics.tag.experimental"), .purple)
        case .wined3d:
            (String(localized: "config.graphics.tag.fallback"), .orange)
        }
    }
}
