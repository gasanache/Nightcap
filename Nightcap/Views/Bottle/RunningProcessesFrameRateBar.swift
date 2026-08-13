//
//  RunningProcessesFrameRateBar.swift
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

// MARK: - Frame rate

extension RunningProcessesView {
    /// Live frame rate, shown only once the log actually carries readings.
    ///
    /// Wine reports frame rate through its `fps` debug channel, which the
    /// Diagnostics On preset enables. Nothing appears until a program is
    /// running with that channel on.
    @ViewBuilder
    var frameRateBar: some View {
        if let current = frameRate.current {
            HStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(current, format: .number.precision(.fractionLength(0)))
                        .font(.system(.title2, design: .monospaced, weight: .medium))
                        .contentTransition(.numericText())
                        .animation(.default, value: current)
                    Text("fps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider().frame(height: 18)

                if let average = frameRate.average {
                    frameRateStat("processes.fps.average", value: average)
                }
                if let minimum = frameRate.minimum {
                    frameRateStat("processes.fps.minimum", value: minimum)
                }

                Spacer()

                Button("processes.fps.reset") { frameRate.reset() }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    private func frameRateStat(_ label: LocalizedStringKey, value: Double) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value, format: .number.precision(.fractionLength(0)))
                .font(.system(.caption, design: .monospaced))
        }
    }
}
