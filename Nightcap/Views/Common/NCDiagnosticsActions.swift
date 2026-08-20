//
//  NCDiagnosticsActions.swift
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

import AppKit
import NightcapKit
import SwiftUI

/// The two ways out of a failure, offered the same way every time.
///
/// This pair — copy the details, open the logs — is written out three times in
/// the app with three different catalogue keys for the same button. Being one
/// component also means every failure the app reports offers both, rather than
/// whichever one that screen's author happened to add.
struct NCDiagnosticsActions: View {
    /// Built on demand: the report is only worth assembling if it is asked for.
    let report: () -> String
    var showsOpenLogs: Bool = true

    @State private var didCopy = false
    /// Held so a second press replaces the countdown rather than racing it.
    @State private var resetTask: Task<Void, Never>?

    private static let confirmationSeconds: Duration = .seconds(2)

    var body: some View {
        HStack(spacing: Theme.Space.snug) {
            Button(didCopy ? "diagnostics.copied" : "diagnostics.copy") {
                copy()
            }
            .disabled(didCopy)
            if showsOpenLogs {
                Button("diagnostics.openLogs") {
                    NSWorkspace.shared.open(Wine.logsFolder)
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .onDisappear { resetTask?.cancel() }
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(report(), forType: .string)
        didCopy = true
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: Self.confirmationSeconds)
            guard !Task.isCancelled else { return }
            didCopy = false
        }
    }
}

/// One destructive confirmation, with one button order.
///
/// The checkbox-accessory `NSAlert` was written out verbatim in two places, and
/// they are the only two confirmations in the app wearing system chrome rather
/// than a SwiftUI alert. This deduplicates them without converting the
/// modality, which would be a behaviour change rather than a design one.
///
/// - Returns: whether the user confirmed, and the checkbox state — always
///   `false` when `rememberTitle` is nil.
///
/// The titles are `String.LocalizationValue` rather than `LocalizedStringKey`:
/// `NSAlert` takes plain strings, and `String(localized:)` — the only way to
/// resolve a key outside a `Text` — accepts that type and not the SwiftUI one.
@MainActor
func ncConfirm(
    title: String.LocalizationValue,
    message: String,
    confirmTitle: String.LocalizationValue,
    isDestructive: Bool = false,
    rememberTitle: String.LocalizationValue? = nil
) -> (confirmed: Bool, remember: Bool) {
    let alert = NSAlert()
    // One of the few places `String(localized:)` is right: AppKit takes String,
    // so the key has to be resolved here rather than handed to a Text.
    alert.messageText = String(localized: title)
    alert.informativeText = message
    // `.warning` even when destructive. `.critical` stamps a caution badge on
    // the icon, which macOS reserves for the genuinely dangerous; removing a
    // bottle from a list is not that, and deriving the style from
    // `isDestructive` silently escalated an alert that used to be a warning.
    // The destructive role lives on the button, where it belongs.
    alert.alertStyle = .warning

    let confirm = alert.addButton(withTitle: String(localized: confirmTitle))
    confirm.hasDestructiveAction = isDestructive
    alert.addButton(withTitle: String(localized: "button.cancel"))

    var checkbox: NSButton?
    if let rememberTitle {
        let button = NSButton(checkboxWithTitle: String(localized: rememberTitle), target: nil, action: nil)
        button.state = .off
        alert.accessoryView = button
        checkbox = button
    }

    let confirmed = alert.runModal() == .alertFirstButtonReturn
    return (confirmed, checkbox?.state == .on)
}
