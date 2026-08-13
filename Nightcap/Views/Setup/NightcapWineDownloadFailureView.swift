//
//  NightcapWineDownloadFailureView.swift
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
import SwiftUI

extension NightcapWineDownloadView {
    func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle")
                .resizable()
                .foregroundStyle(.red)
                .frame(width: 80, height: 80)
                .padding(.bottom, 8)
            Text(error)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("setup.nightcapwine.copyDiagnostics") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        diagnostics.reportString(stage: "download", error: error),
                        forType: .string
                    )
                }
                .buttonStyle(.bordered)

                Button("open.logs") {
                    NightcapApp.openLogsFolder()
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                Button("setup.retry") {
                    retryDownload()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

                Button("setup.quit") {
                    showSetup = false
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.top, 8)
        }
        .padding()
        // The panel stacks its content leading-aligned, so without this the
        // whole failure block sits left of the card rather than under it.
        .frame(maxWidth: .infinity)
    }
}
