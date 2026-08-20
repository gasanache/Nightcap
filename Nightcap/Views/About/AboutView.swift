//
//  AboutView.swift
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

/// Sizes particular to the About window.
///
/// The width comes from ``ViewWidth`` like every other window; only the pieces
/// this screen invents — the icon and its header — are named here.
private enum AboutMetric {
    /// Large enough to read as the app's mark rather than a list glyph.
    static let icon: CGFloat = 88
    /// The icon casts a soft shadow so it sits above the tinted header rather
    /// than being pasted onto it.
    static let iconShadow: CGFloat = 10
    static let iconShadowOpacity: Double = 0.22
    static let iconShadowOffset: CGFloat = 4
    /// The header's wash: strongest behind the icon, gone by the divider.
    static let tintTop: Double = 0.20
    /// The night indigo the app icon is built from.
    ///
    /// This was `Color.accentColor`, on the reasoning that it would follow the
    /// user's Mac — but Nightcap ships an `AccentColor` asset pinned to system
    /// orange, so it was never the user's colour, it was the brand's. At low
    /// opacity over a dark window that orange rendered as brown, directly
    /// behind an icon that is navy and amber. Taking the tint from the icon
    /// instead makes the header and the mark agree.
    static let tint = Color(red: 66 / 255, green: 72 / 255, blue: 148 / 255)
    /// Clearance for the traffic lights, which float over the header because
    /// the window has no title bar of its own.
    static let titleBarInset: CGFloat = 28
    /// How long the copy button holds its checkmark.
    static let copyFeedback: Duration = .seconds(2)
}

/// What Nightcap is, which version of it you are running, and where it came
/// from.
///
/// The stock macOS About panel could have shown the first two, and only as far
/// as `Info.plist` describes them. The thing worth knowing about a Wine
/// front-end is which *engine* is underneath it — that moves independently of
/// the app, and it is the first question any bug report has to answer — so the
/// runtime's own versions are the body of this window, and one button puts all
/// of it on the clipboard.
struct AboutView: View {
    @Environment(\.openURL) private var openURL

    /// Read once when the window opens rather than in `body`: it decodes a
    /// plist off disk, and `body` runs on every hover and window resize.
    @State private var runtime: NightcapWineVersion?
    @State private var didCopy = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            details
        }
        .frame(width: ViewWidth.small)
        .task { runtime = NightcapWineInstaller.nightcapWineInfo() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Theme.Space.card) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: AboutMetric.icon, height: AboutMetric.icon)
                .shadow(
                    color: .black.opacity(AboutMetric.iconShadowOpacity),
                    radius: AboutMetric.iconShadow,
                    y: AboutMetric.iconShadowOffset
                )

            VStack(spacing: Theme.Space.tight) {
                // The app's own name, never translated.
                Text(verbatim: AboutInfo.appName)
                    .font(.system(.largeTitle, weight: .semibold))
                // A version is something the computer reads back, so it takes
                // the monospaced role — and it is selectable, because the only
                // reason to look at it is to paste it somewhere.
                Text(verbatim: AboutInfo.versionLine)
                    .font(Theme.Typography.machine)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AboutMetric.titleBarInset)
        .padding(.bottom, Theme.Space.card + Theme.Space.snug)
        // `ignoresSafeArea` is load-bearing: the window hides its title bar but
        // still reserves the strip, and without this the wash stopped at the
        // traffic lights and left a seam across the top of the window. It fades
        // to fully clear rather than to a low opacity, so the header meets the
        // divider instead of ending on a second, fainter edge just above it.
        .background {
            LinearGradient(
                colors: [
                    AboutMetric.tint.opacity(AboutMetric.tintTop),
                    AboutMetric.tint.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Body

    private var details: some View {
        VStack(spacing: Theme.Space.card) {
            engineCard
            repositoryButton
            secondaryLinks
            footer
        }
        .padding(Theme.Space.card)
    }

    /// The engine, not the app. A missing runtime is a real state — it is
    /// downloaded separately, and a fresh install has none — so it is reported
    /// rather than left as blank rows.
    private var engineCard: some View {
        NCCard {
            VStack(spacing: Theme.Space.snug) {
                if let runtime {
                    specRow("Wine Libraries", value: AboutInfo.runtimeVersion(runtime))
                    if let dxvk = runtime.dxvkVersion {
                        Divider()
                        specRow("DXVK", value: dxvk)
                    }
                    if let dxmt = runtime.dxmtVersion {
                        Divider()
                        specRow("DXMT", value: dxmt)
                    }
                } else {
                    HStack(spacing: Theme.Space.snug) {
                        specLabel("Wine Libraries")
                        Spacer(minLength: Theme.Space.snug)
                        NCStatusBadge(status: .missing, label: "dependency.notInstalled")
                    }
                }
            }
        }
    }

    /// Engine names are products, not prose — "DXVK" is "DXVK" in every
    /// language — so they are `verbatim` rather than catalogue keys.
    private func specRow(_ title: String, value: String) -> some View {
        HStack(spacing: Theme.Space.snug) {
            specLabel(title)
            Spacer(minLength: Theme.Space.snug)
            Text(verbatim: value)
                .font(Theme.Typography.machine)
                .textSelection(.enabled)
        }
    }

    private func specLabel(_ title: String) -> some View {
        Text(verbatim: title)
            .font(Theme.Typography.rowCaption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Links

    /// The address itself, not a word standing in for it. Anyone opening an
    /// About window to find the source wants the URL they can read out or
    /// retype, so it is the label — monospaced, because it is an address.
    private var repositoryButton: some View {
        Button {
            open(AboutInfo.repository)
        } label: {
            HStack(spacing: Theme.Space.snug) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                Text(verbatim: AboutInfo.repositoryDisplay)
                    .font(Theme.Typography.machine)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(Theme.Typography.detail)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .help("about.link.repository.help")
    }

    private var secondaryLinks: some View {
        HStack(spacing: Theme.Space.row) {
            linkButton("help.issues", symbol: "ladybug", address: AboutInfo.issues)
            linkButton("about.link.license", symbol: "doc.text", address: AboutInfo.license)
            Spacer(minLength: Theme.Space.snug)
            copyButton
        }
    }

    private func linkButton(
        _ title: LocalizedStringKey,
        symbol: String,
        address: String
    ) -> some View {
        Button {
            open(address)
        } label: {
            Label(title, systemImage: symbol)
                .font(Theme.Typography.rowCaption)
                // The ladybug is a multicolour symbol; left alone it renders
                // red-and-blue beside a monochrome document glyph, so the two
                // links in this row would not look like the same kind of thing.
                .symbolRenderingMode(.monochrome)
        }
        .buttonStyle(.link)
    }

    /// Everything above, as text, for pasting into an issue.
    ///
    /// Only the glyph changes on success. Swapping the label for "Copied"
    /// would resize the button under the pointer that just hit it, and this
    /// window has no toast layer to report from instead.
    private var copyButton: some View {
        Button {
            copyVersions()
        } label: {
            Label(
                "Copy to Clipboard",
                systemImage: didCopy ? "checkmark" : "doc.on.doc"
            )
            .font(Theme.Typography.rowCaption)
        }
        .controlSize(.small)
        .disabled(didCopy)
    }

    private func copyVersions() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(AboutInfo.versionReport(runtime), forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: AboutMetric.copyFeedback)
            didCopy = false
        }
    }

    // MARK: - Footer

    /// The license and the lineage. Nightcap is GPL-3.0 and stands on two
    /// projects that came before it; saying so is both what the license asks
    /// for and simply true.
    private var footer: some View {
        VStack(spacing: Theme.Space.tight) {
            Text("about.license")
            Text("about.lineage")
        }
        .font(Theme.Typography.detail)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    /// Addresses are strings because a `URL` literal cannot be written without
    /// a force-unwrap; the conversion happens here, failing quietly, exactly as
    /// the Help menu already does it.
    private func open(_ address: String) {
        guard let url = URL(string: address) else { return }
        openURL(url)
    }
}

#Preview {
    AboutView()
}
