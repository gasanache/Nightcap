//
//  AudioConfigSection.swift
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

/// The main Audio section composing status, test buttons, settings, and findings.
///
/// Placed in ConfigView between Graphics and Performance, matching the
/// section-per-subsystem pattern established in Phase 4.
struct AudioConfigSection: View {
    @ObservedObject var bottle: Bottle

    @State private var monitor = AudioDeviceMonitor()

    @State private var audioStatus: AudioStatus = .unknown
    @State private var probeResults: [AudioProbeResult] = []
    @State private var lastTestedDate: Date?
    @State private var showTroubleshootingWizard: Bool = false
    @State private var deviceHistory = AudioDeviceHistory()

    /// Debounce timer for Bluetooth device change events.
    @State private var debounceTask: Task<Void, Never>?

    /// The troubleshooting engine, created when the wizard opens.
    @State private var troubleshootingEngine: AudioTroubleshootingEngine?

    var body: some View {
        Section("Audio") {
            // 1. Status line
            AudioStatusView(
                audioStatus: audioStatus,
                lastTestedDate: lastTestedDate,
                defaultDeviceName: monitor.defaultOutputDevice()?.name,
                transportType: monitor.defaultOutputDevice()?.transportType,
                sampleRate: monitor.defaultOutputDevice()?.sampleRate,
                channelCount: monitor.defaultOutputDevice()?.outputChannelCount
            )

            // 2. Test buttons row
            AudioTestButtonsView(
                bottle: bottle,
                onStatusUpdate: { status in
                    audioStatus = status
                    lastTestedDate = Date()
                },
                onTestComplete: { results in
                    probeResults = results
                },
                testExeURL: Bundle.main.url(forResource: "NightcapAudioTest", withExtension: "exe")
            )

            // 3. Simple/Advanced toggle

            // 4. Settings
            AudioSettingsView(bottle: bottle, advancedMode: true)

            // 5. Badge if advanced overrides in Simple mode

            // 6. Findings (if any from last test)
            if !currentFindings.isEmpty {
                AudioFindingsView(findings: currentFindings, onApplyFix: handleApplyFix)
            }

            // 7. Advanced device views
            advancedDeviceViews

            // 8. Troubleshooting link
            Button("Audio Troubleshooting\u{2026}") {
                openTroubleshootingWizard()
            }
        }
        .onAppear {
            startDeviceListening()
        }
        .sheet(isPresented: $showTroubleshootingWizard) {
            if let engine = troubleshootingEngine {
                AudioTroubleshootingWizardView(
                    engine: engine,
                    onDismiss: {
                        showTroubleshootingWizard = false
                    },
                    onApplyFix: { actionId in
                        await AudioFixActions.apply(actionId, to: bottle)
                    },
                    // Every audio option is already on screen, so there is
                    // nothing left for this to reveal.
                    onOpenAdvanced: {}
                )
            }
        }
    }
}

// MARK: - Computed Properties

extension AudioConfigSection {
    /// Aggregated findings from the most recent probe results.
    private var currentFindings: [AudioFinding] {
        probeResults.flatMap(\.findings)
    }
}

// MARK: - Advanced Overrides Badge

extension AudioConfigSection {}

// MARK: - Advanced Device Views

extension AudioConfigSection {
    private var advancedDeviceViews: some View {
        Group {
            // Always visible.
            VStack(alignment: .leading, spacing: 10) {
                AudioDeviceListView(devices: monitor.allOutputDevices())
            }

            // Always visible.
            VStack(alignment: .leading, spacing: 10) {
                AudioDeviceHistoryView(history: deviceHistory)
            }
        }
    }
}

// MARK: - Fix Application

extension AudioConfigSection {
    private func handleApplyFix(_ actionId: String) {
        Task { @MainActor in
            await AudioFixActions.apply(actionId, to: bottle)
        }
    }
}

// MARK: - Troubleshooting Wizard

extension AudioConfigSection {
    private func openTroubleshootingWizard() {
        let probes: [any AudioProbe] = [
            CoreAudioDeviceProbe(monitor: monitor),
            WineRegistryAudioProbe(bottle: bottle),
            WineAudioTestProbe(
                bottle: bottle,
                testExeURL: Bundle.main.url(forResource: "NightcapAudioTest", withExtension: "exe")
            )
        ]
        troubleshootingEngine = AudioTroubleshootingEngine(probes: probes)
        showTroubleshootingWizard = true
    }
}

// MARK: - Device Listening

extension AudioConfigSection {
    private func startDeviceListening() {
        // AudioDeviceMonitor dispatches on DispatchQueue.main.
        // The @Sendable closure annotation causes a compiler warning,
        // but mutation is main-thread-safe since the callback runs on main queue.
        monitor.startListening { event in
            // Record event in session history
            deviceHistory.append(event)

            // Debounce status update for Bluetooth connections (2-3 second delay)
            // to avoid spurious state changes during BT negotiation.
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                audioStatus = .unknown
            }
        }
    }
}
