//
//  DPIConfigSheetView.swift
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

/// One question and its answer: how large should Windows think the display is.
///
/// Was a hand-rolled sheet — a bold `Text` and a `Divider` standing in for a
/// title bar, a `GroupBox` around the preview, a `Spacer` pushing two buttons
/// down — at a height of 240 that belonged to no scale. The slider, the field
/// and the live preview are unchanged; the frame around them is the shared one.
struct DPIConfigSheetView: View {
    @Binding var dpiConfig: Int
    @Binding var isRetinaMode: Bool
    @Binding var presented: Bool
    @State var stagedChanges: Float
    @FocusState var textFocused: Bool

    /// Points per inch at 100%. The preview renders a nominal 10pt run of text
    /// at the staged DPI, halved on Retina where Wine draws at 2x.
    private static let pointsPerInch: CGFloat = 72
    private static let previewNominalSize: CGFloat = 10
    /// The preview well is fixed rather than sized by its text: at 480 DPI the
    /// sample outgrows the sheet, and a well that resizes as you drag the
    /// slider makes the controls below it jump.
    private static let previewHeight: CGFloat = 72
    private static let dpiFieldWidth: CGFloat = 40

    init(dpiConfig: Binding<Int>, isRetinaMode: Binding<Bool>, presented: Binding<Bool>) {
        self._dpiConfig = dpiConfig
        self._isRetinaMode = isRetinaMode
        self._presented = presented
        self.stagedChanges = Float(dpiConfig.wrappedValue)
    }

    var body: some View {
        NCSheet(
            title: "configDpi.title",
            width: ViewWidth.medium,
            height: ViewHeight.compact
        ) {
            VStack(alignment: .leading, spacing: Theme.Space.row) {
                NCGroupLabel(title: "configDpi.preview", systemImage: "text.magnifyingglass")
                previewWell
                dpiControls
            }
        } footer: {
            NCFooterSpacer()
            Button("create.cancel") {
                presented = false
            }
            .keyboardShortcut(.cancelAction)
            Button("button.ok") {
                dpiConfig = Int(stagedChanges)
                presented = false
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Subviews

    private var previewFontSize: CGFloat {
        Self.previewNominalSize * CGFloat(stagedChanges) / Self.pointsPerInch
            * (isRetinaMode ? 0.5 : 1)
    }

    private var previewWell: some View {
        Text("configDpi.previewText")
            .font(.system(size: previewFontSize))
            .padding(Theme.Space.row)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.previewHeight, alignment: .topLeading)
            .background(.quaternary.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .clipped()
    }

    private var dpiControls: some View {
        HStack(spacing: Theme.Space.snug) {
            Slider(value: $stagedChanges, in: 96 ... 480, step: 24, onEditingChanged: { _ in
                textFocused = false
            })
            TextField(String(), value: $stagedChanges, format: .number)
                .frame(width: Self.dpiFieldWidth)
                .focused($textFocused)
            Text("configDpi.dpi")
        }
    }
}
