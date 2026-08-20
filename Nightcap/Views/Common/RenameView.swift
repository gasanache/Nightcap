//
//  RenameView.swift
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

/// One question and its answer.
///
/// Was a `NavigationStack` wrapped around a grouped `Form` purely to get a title
/// bar and two toolbar buttons — chrome no other sheet in the app wore, sized by
/// `fixedSize` so its height was whatever the form happened to measure. The
/// question, the field and the two buttons are the same; only the frame around
/// them is now the shared one.
struct RenameView: View {
    /// A fixed caller-supplied label — "Rename bottle", "Rename pin" — so a key
    /// rather than the `Text` this used to keep, which `NCSheet` cannot take.
    let title: LocalizedStringKey
    var renameAction: (String) -> Void

    @State private var name: String = ""
    @Environment(\.dismiss) private var dismiss

    init(_ title: LocalizedStringKey, name: String, renameAction: @escaping (String) -> Void) {
        self.title = title
        self._name = State(initialValue: name)
        self.renameAction = renameAction
    }

    var body: some View {
        NCSheet(
            title: title,
            width: ViewWidth.small,
            height: ViewHeight.compact
        ) {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                NCGroupLabel(title: "rename.name")
                // The field's own label is hidden rather than dropped, so
                // VoiceOver still announces "New name" while the drawn label
                // above it is not said twice.
                TextField("rename.name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .onSubmit {
                        submit()
                    }
            }
        } footer: {
            NCFooterSpacer()
            Button("create.cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            Button("rename.rename") {
                submit()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!isNameValid)
        }
    }

    var isNameValid: Bool {
        !name.isEmpty
    }

    func submit() {
        // Return in the field used to bypass the disabled button: a cleared
        // name renamed the bottle (or pin) to the empty string.
        guard isNameValid else { return }
        renameAction(name)
        dismiss()
    }
}
