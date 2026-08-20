//
//  RunningProcessesView.swift
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

struct RunningProcessesView: View {
    @Environment(NCToastCenter.self) private var toastCentre

    @ObservedObject var bottle: Bottle
    @StateObject private var viewModel: ProcessesViewModel
    @State private var showStopConfirmation: Bool = false
    @State private var showForceStopConfirmation: Bool = false
    @State private var showingDetail: Bool = false
    /// Not private: the frame-rate bar lives in its own file to keep this one
    /// inside the file-length limit.
    @StateObject var frameRate = FrameRateMonitor()

    init(bottle: Bottle) {
        self.bottle = bottle
        _viewModel = StateObject(wrappedValue: ProcessesViewModel(bottle: bottle))
    }

    var body: some View {
        ZStack {
            if viewModel.filteredProcesses.isEmpty, viewModel.shutdownState == .idle {
                emptyStateView
            } else {
                processListView
            }
            if viewModel.shutdownState != .idle {
                shutdownOverlay
            }
        }
        .navigationTitle("tab.processes")
        .safeAreaInset(edge: .top) { frameRateBar }
        .toolbar { processToolbar }
        .onAppear {
            viewModel.startPolling()
            frameRate.start()
        }
        .onDisappear {
            viewModel.stopPolling()
            frameRate.stop()
        }
        .confirmationDialog(
            String(localized: "process.confirm.stop.title"),
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            stopConfirmationButtons
        } message: {
            stopConfirmationMessage
        }
        .confirmationDialog(
            String(localized: "process.confirm.forceStop.title"),
            isPresented: $showForceStopConfirmation,
            titleVisibility: .visible
        ) {
            forceStopConfirmationButtons
        } message: {
            Text("process.confirm.forceStop.message")
        }
    }

    // MARK: - Empty State

    /// Two different absences. While the poll is in flight the screen is
    /// waiting, and a spinner says so better than a glyph; once it has looked
    /// and found nothing, it is an empty state with the one way out on it.
    @ViewBuilder
    private var emptyStateView: some View {
        if viewModel.isPolling {
            VStack(spacing: Theme.Space.row) {
                ProgressView()
                    .controlSize(.small)
                Text("process.checking")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            NCEmptyState(
                systemImage: "cpu",
                title: "process.empty",
                message: "process.empty.message"
            ) {
                Button("process.action.refresh") {
                    Task { await viewModel.refreshProcessList() }
                }
            }
        }
    }

    // MARK: - Shutdown Overlay

    private var shutdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                switch viewModel.shutdownState {
                case .stopping:
                    Text("process.stopping")
                case .forceKilling:
                    Text("process.forceStopping")
                case .idle:
                    EmptyView()
                }
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Confirmation Dialogs

    @ViewBuilder
    private var stopConfirmationButtons: some View {
        Button(String(localized: "process.action.stopBottle"), role: .destructive) {
            Task {
                let count = await viewModel.stopBottle()
                withAnimation {
                    toastCentre.show(
                        String(localized: "process.toast.stopped \(count)"),
                        status: .ready
                    )
                }
            }
        }
        Button("button.cancel", role: .cancel) {}
    }

    @ViewBuilder
    private var stopConfirmationMessage: some View {
        let hasUntracked = viewModel.processes.contains { $0.source == .untracked }
        if hasUntracked {
            Text("process.confirm.stop.message")
                + Text("\n")
                + Text("process.confirm.stop.includesUntracked")
        } else {
            Text("process.confirm.stop.message")
        }
    }

    @ViewBuilder
    private var forceStopConfirmationButtons: some View {
        Button(String(localized: "process.action.forceStop"), role: .destructive) {
            Task {
                let count = await viewModel.forceStopBottle()
                withAnimation {
                    toastCentre.show(
                        String(localized: "process.toast.stopped \(count)"),
                        status: .ready
                    )
                }
            }
        }
        Button("button.cancel", role: .cancel) {}
    }
}

// MARK: - Process List & Detail

extension RunningProcessesView {
    var processListView: some View {
        VStack(spacing: 0) {
            List(viewModel.filteredProcesses, selection: $viewModel.selectedProcessID) { process in
                processRow(process)
            }
            .contextMenu(forSelectionType: Int32.self) { selectedIDs in
                if let processID = selectedIDs.first,
                   let process = viewModel.filteredProcesses.first(where: { $0.id == processID }) {
                    processContextMenu(for: process)
                }
            } primaryAction: { _ in }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showingDetail,
               let selectedID = viewModel.selectedProcessID,
               let process = viewModel.filteredProcesses.first(where: { $0.id == selectedID }) {
                processDetailView(for: process)
            }
        }
    }

    /// One process, as a row rather than six columns.
    ///
    /// The image name is the subject and it is a filename, so it takes the
    /// machine treatment rather than being set in prose; the PID and the memory
    /// figure are values read back off `tasklist`, so they share the row's
    /// machine slot. What remains — the kind, where the process came from, how
    /// long it has been up — is what the row says about its subject.
    func processRow(_ process: WineProcess) -> some View {
        NCRow(
            title: process.imageName,
            caption: localizedKind(process.kind),
            machine: machineDetail(for: process),
            isMachineTitle: true
        ) {
            HStack(spacing: Theme.Space.row) {
                sourceLabel(for: process)
                startedLabel(for: process)
                // A process in this list is, by definition, up. The adapter is
                // still where that becomes a colour, so the badge agrees with
                // every other status in the app.
                NCStatusBadge(
                    status: NCStatus(exitCode: nil, isRunning: true),
                    label: "process.status.running"
                )
            }
        }
    }

    func machineDetail(for process: WineProcess) -> String {
        let pidLabel = String(localized: "process.column.pid")
        return "\(pidLabel) \(process.winePID) · \(process.memoryUsage)"
    }

    /// Untracked stays orange: it is the one thing in the row that says
    /// Nightcap did not start this and cannot vouch for what stopping it does.
    func sourceLabel(for process: WineProcess) -> some View {
        Text(localizedSource(process.source))
            .font(Theme.Typography.detail)
            .foregroundStyle(process.source == .untracked ? Color.orange : Color.secondary)
    }

    /// Untracked processes have no launch time — the column used to fill that
    /// gap with a dash, which a row does not need.
    @ViewBuilder
    func startedLabel(for process: WineProcess) -> some View {
        if let launchTime = process.launchTime {
            Text(launchTime, style: .relative)
                .font(Theme.Typography.detail)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    func processContextMenu(for process: WineProcess) -> some View {
        Button {
            Task { await viewModel.quitProcess(process) }
        } label: {
            Label("process.action.quit", systemImage: "xmark.circle")
        }
        .disabled(viewModel.shutdownState != .idle)

        Button {
            Task { await viewModel.forceQuitProcess(process) }
        } label: {
            Label("process.action.forceQuit", systemImage: "xmark.circle.fill")
        }
        .disabled(viewModel.shutdownState != .idle)

        Divider()

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(String(process.winePID), forType: .string)
        } label: {
            Label("process.action.copyPID", systemImage: "doc.on.clipboard")
        }

        Button {
            withAnimation { showingDetail.toggle() }
        } label: {
            Label("process.action.showDetails", systemImage: "info.circle")
        }
    }

    func processDetailView(for process: WineProcess) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    detailRow(label: "process.column.name", value: process.imageName)
                    detailRow(label: "process.detail.winePID", value: String(process.winePID))
                    if let macosPID = process.macosPID {
                        detailRow(label: "process.detail.macosPID", value: String(macosPID))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    detailRow(label: "process.detail.source", value: localizedSource(process.source))
                    detailRow(label: "process.detail.kind", value: localizedKind(process.kind))
                    if let commandLine = process.commandLine {
                        detailRow(label: "process.column.command", value: commandLine)
                    }
                }
                Spacer()
            }
            if process.kind == .system || process.kind == .service {
                Label("process.detail.systemWarning", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    func detailRow(label: LocalizedStringResource, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Toolbar & Helpers

extension RunningProcessesView {
    @ToolbarContentBuilder
    var processToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Picker("process.filter.label", selection: $viewModel.filterMode) {
                Text("process.filter.apps").tag(ProcessesViewModel.FilterMode.appsOnly)
                Text("process.filter.all").tag(ProcessesViewModel.FilterMode.all)
            }
            .pickerStyle(.segmented)

            Button {
                Task { await viewModel.refreshProcessList() }
            } label: {
                Label("process.action.refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)

            Button {
                showStopConfirmation = true
            } label: {
                Label("process.action.stopBottle", systemImage: "stop.circle")
            }
            .disabled(viewModel.shutdownState != .idle)
            .keyboardShortcut(.delete, modifiers: .command)

            Button {
                showForceStopConfirmation = true
            } label: {
                Label("process.action.forceStop", systemImage: "stop.circle.fill")
            }
            .disabled(viewModel.shutdownState != .idle)
        }
    }

    func localizedKind(_ kind: ProcessKind) -> String {
        switch kind {
        case .app: String(localized: "process.kind.app")
        case .service: String(localized: "process.kind.service")
        case .system: String(localized: "process.kind.system")
        }
    }

    func localizedSource(_ source: ProcessSource) -> String {
        switch source {
        case .nightcap: String(localized: "process.source.nightcap")
        case .untracked: String(localized: "process.source.untracked")
        }
    }
}
