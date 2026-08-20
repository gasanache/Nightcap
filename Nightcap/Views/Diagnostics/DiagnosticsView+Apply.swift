//
//  DiagnosticsView+Apply.swift
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

// MARK: - Remediation application

extension DiagnosticsView {
    /// An explicit handler wins; otherwise the built-in applicator runs when a
    /// bottle was provided. Nil — no bottle, no handler — makes the cards hide
    /// their action buttons instead of drawing ones that do nothing.
    var effectiveOnAction: ((RemediationAction) -> Void)? {
        if let onAction { return onAction }
        guard bottle != nil else { return nil }
        return { applyRemediation($0) }
    }

    /// Applies a remediation against the bottle, honestly reporting what
    /// happened. Install actions stream a real winetricks run.
    func applyRemediation(_ action: RemediationAction) {
        guard let bottle else { return }
        Task { @MainActor in
            switch action.actionType {
            case .switchBackend:
                applySwitchBackend(action, bottle: bottle)
            case .changeSetting:
                applyChangeSetting(action, bottle: bottle)
            case .installVerb:
                await applyInstallVerb(action, bottle: bottle)
            case .informational:
                break
            }
        }
    }

    private func applySwitchBackend(_ action: RemediationAction, bottle: Bottle) {
        if let raw = action.settingValue, let backend = GraphicsBackend(rawValue: raw) {
            bottle.settings.graphicsBackend = backend
            applyMessage = String(localized: "diagnostics.applied \(action.title)")
        } else {
            applyMessage = String(localized: "diagnostics.applyFailed \(action.title)")
        }
    }

    private func applyChangeSetting(_ action: RemediationAction, bottle: Bottle) {
        switch (action.settingKeyPath, action.settingValue) {
        case let ("metalConfig.forceD3D11", value?):
            bottle.settings.forceD3D11 = value == "true"
            applyMessage = String(localized: "diagnostics.applied \(action.title)")
        case let ("metalConfig.dxrEnabled", value?):
            bottle.settings.dxrEnabled = value == "true"
            applyMessage = String(localized: "diagnostics.applied \(action.title)")
        default:
            applyMessage = String(localized: "diagnostics.applyFailed \(action.title)")
        }
    }

    private func applyInstallVerb(_ action: RemediationAction, bottle: Bottle) async {
        guard let verb = action.winetricksVerb else {
            applyMessage = String(localized: "diagnostics.applyFailed \(action.title)")
            return
        }
        applyMessage = String(localized: "diagnostics.installing \(verb)")
        var failed = false
        for await (_, progress) in Winetricks.installVerbs([verb], for: bottle) {
            if case let .completed(code) = progress, code != 0 { failed = true }
            if case .failed = progress { failed = true }
            if case .timedOut = progress { failed = true }
        }
        applyMessage = failed
            ? String(localized: "diagnostics.applyFailed \(action.title)")
            : String(localized: "diagnostics.applied \(action.title)")
    }
}

// MARK: - Remediation cards

extension DiagnosticsView {
    var remediationCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(primaryRemediations) { action in
                RemediationCardView(
                    action: action,
                    confidenceTier: diagnosis.map { confidenceTier(for: action, diagnosis: $0) } ?? .low,
                    onAction: effectiveOnAction
                )
            }

            if !lowConfidenceRemediations.isEmpty {
                DisclosureGroup(
                    isExpanded: $isOtherSuggestionsExpanded
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(lowConfidenceRemediations) { action in
                            RemediationCardView(
                                action: action,
                                confidenceTier: .low,
                                onAction: effectiveOnAction
                            )
                        }
                    }
                } label: {
                    Text("Other things to try")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Log Section
