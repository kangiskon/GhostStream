import SwiftUI

struct GhostStreamShellView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel

    @State private var selection: GhostStreamSection = .home

    var body: some View {
        TabView(selection: $selection) {
            GhostDashboardView(selection: $selection)
                .tabItem { Label("Home", systemImage: GhostStreamSection.home.icon) }
                .tag(GhostStreamSection.home)

            GhostLibraryHubView()
                .tabItem { Label("Library", systemImage: GhostStreamSection.library.icon) }
                .tag(GhostStreamSection.library)

            DeviceCommandCenterOverview()
                .tabItem { Label("Devices", systemImage: GhostStreamSection.devices.icon) }
                .tag(GhostStreamSection.devices)

            IntelligenceCommandCenterOverview()
                .tabItem { Label("Intelligence", systemImage: GhostStreamSection.intelligence.icon) }
                .tag(GhostStreamSection.intelligence)

            GhostMoreView()
                .tabItem { Label("More", systemImage: GhostStreamSection.more.icon) }
                .tag(GhostStreamSection.more)
        }
        .tint(Theme.accentBright)
    }
}

private struct DeviceCommandCenterOverview: View {
    @EnvironmentObject private var accountStore: AccountStore

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        commandTitle("Devices", subtitle: "Trusted devices connected to your GhostStream account")

                        if accountStore.devices.isEmpty {
                            overviewEmpty(
                                icon: "qrcode",
                                title: "Pair your first device",
                                detail: "QR and 6-digit Apple TV pairing will appear here once the trusted-device service is connected."
                            )
                        } else {
                            ForEach(accountStore.devices) { device in
                                HStack(spacing: 14) {
                                    Image(systemName: device.platform == "tvos" ? "appletv.fill" : "iphone")
                                        .font(.title2)
                                        .foregroundStyle(Theme.accentBright)
                                        .frame(width: 48, height: 48)
                                        .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(device.displayName).font(.headline)
                                        Text("(device.platform.uppercased()) • (device.trustState.capitalized)")
                                            .font(.caption)
                                            .foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    Circle()
                                        .fill(device.revokedAt == nil ? Color.green : Color.red)
                                        .frame(width: 9, height: 9)
                                }
                                .padding(16)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct IntelligenceCommandCenterOverview: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        commandTitle("Intelligence", subtitle: "Source health, compatibility, and playback diagnostics")

                        VStack(alignment: .leading, spacing: 14) {
                            Label("Source Health", systemImage: "heart.text.square.fill")
                                .font(.headline)
                            Text(store.activeSource?.name ?? "No source connected")
                                .font(.title3.weight(.bold))
                            Text(intelligenceStatus)
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)

                            HStack {
                                intelligenceMetric("LIVE", value: "(library.channels.count)")
                                intelligenceMetric("MOVIES", value: "(library.movies.count)")
                                intelligenceMetric("SERIES", value: "(library.series.count)")
                            }
                        }
                        .padding(18)
                        .background(Theme.cardGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))

                        overviewEmpty(
                            icon: "waveform.path.ecg",
                            title: "Full diagnostics are next",
                            detail: "Latency, bitrate, codecs, buffering history, compatibility checks, and recommendations will populate this command center from real measurements."
                        )
                    }
                    .padding(16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var intelligenceStatus: String {
        if library.isLoading { return "Refreshing source and library status…" }
        if let error = library.errorMessage, !error.isEmpty { return error }
        if store.activeSource != nil && library.loadedSourceID == store.activeSourceID { return "Source is connected and library metadata is available." }
        return "Run source diagnostics after connecting an authorized source."
    }

    private func intelligenceMetric(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}

private func commandTitle(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
        Text(title.uppercased())
            .font(.system(size: 26, weight: .black, design: .rounded))
            .tracking(2)
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
    }
}

private func overviewEmpty(icon: String, title: String, detail: String) -> some View {
    HStack(spacing: 14) {
        Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(Theme.accentBright)
            .frame(width: 52, height: 52)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(Theme.muted)
        }
        Spacer()
    }
    .padding(18)
    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
}
