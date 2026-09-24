import SwiftUI

struct GhostDashboardView: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var accountStore: AccountStore

    @Binding var selection: GhostStreamSection

    private var counts: DashboardLibraryCounts {
        DashboardLibraryCounts(
            live: library.channels.count,
            movies: library.movies.count,
            series: library.series.count
        )
    }

    private var sourceHealth: DashboardSourceHealth {
        guard let source = store.activeSource else { return .disconnected }
        if library.isLoading { return .loading }
        if let error = library.errorMessage, !error.isEmpty { return .attention(error) }
        if library.loadedSourceID == source.id { return .connected }
        if let notice = library.refreshNotice, !notice.isEmpty { return .attention(notice) }
        return .attention("GhostStream has not completed a health check for this source yet.")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Theme.background2,
                        Theme.background,
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        commandHero
                        quickActions
                        sourceHealthCard
                        continueWatching
                        pairedDevices
                        recentActivity
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .padding(.bottom, 26)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("GHOSTSTREAM")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .tracking(2)
                Text(accountStore.account?.email ?? "Local Mode")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button {
                selection = .more
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .foregroundStyle(Theme.accentBright)
                    .background(Theme.card, in: Circle())
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var commandHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text("STREAMING COMMAND CENTER")
                        .font(.caption.weight(.heavy))
                        .tracking(1.7)
                        .foregroundStyle(Theme.accentBright)
                    Text(store.activeSource?.name ?? "Connect your media")
                        .font(.title2.weight(.bold))
                    Text(commandSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Theme.accentBright)
                    .shadow(color: Theme.accent.opacity(0.6), radius: 20)
            }

            HStack(spacing: 12) {
                metric("(counts.live)", "LIVE")
                metric("(counts.movies)", "MOVIES")
                metric("(counts.series)", "SERIES")
                metric("(accountStore.devices.filter { $0.revokedAt == nil }.count)", "DEVICES")
            }
        }
        .padding(20)
        .background(Theme.cardGradient)
        .overlay(Theme.heroGlow)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.border, lineWidth: 1))
    }

    private var commandSubtitle: String {
        if store.activeSource == nil {
            return "Add an authorized source, pair your devices, then monitor playback and source health here."
        }
        if counts.total == 0 {
            return "Your source is connected. GhostStream will show library and health information as it becomes available."
        }
        return "(counts.total) library items available across this device."
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            commandButton("Library", icon: "rectangle.stack.fill", section: .library)
            commandButton("Devices", icon: "rectangle.connected.to.line.below", section: .devices)
            commandButton("Intelligence", icon: "waveform.path.ecg.rectangle.fill", section: .intelligence)
        }
    }

    private func commandButton(_ title: String, icon: String, section: GhostStreamSection) -> some View {
        Button {
            selection = section
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.accentBright)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(Theme.card.opacity(0.95), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var sourceHealthCard: some View {
        dashboardSection("Source Health", icon: "heart.text.square.fill") {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Theme.border, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: healthProgress)
                        .stroke(healthColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: healthIcon)
                        .foregroundStyle(healthColor)
                }
                .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 5) {
                    Text(sourceHealth.title)
                        .font(.headline)
                    Text(sourceHealth.detail)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(3)
                }
                Spacer()
                Button("Open") { selection = .intelligence }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accentBright)
            }
        }
    }

    private var healthProgress: CGFloat {
        switch sourceHealth {
        case .connected: return 0.92
        case .loading: return 0.55
        case .attention: return 0.35
        case .disconnected: return 0.08
        }
    }

    private var healthColor: Color {
        switch sourceHealth {
        case .connected: return .green
        case .loading: return Theme.accentBright
        case .attention: return .orange
        case .disconnected: return Theme.muted
        }
    }

    private var healthIcon: String {
        switch sourceHealth {
        case .connected: return "checkmark"
        case .loading: return "arrow.triangle.2.circlepath"
        case .attention: return "exclamationmark"
        case .disconnected: return "minus"
        }
    }

    private var continueWatching: some View {
        dashboardSection("Continue Watching", icon: "play.circle.fill") {
            EmptyDashboardState(
                icon: "play.rectangle",
                title: "Nothing in progress yet",
                detail: "Movies and episodes you start will appear here and sync across your trusted devices."
            )
        }
    }

    private var pairedDevices: some View {
        dashboardSection("Paired Devices", icon: "rectangle.connected.to.line.below") {
            if accountStore.devices.isEmpty {
                EmptyDashboardState(
                    icon: "qrcode",
                    title: "No paired devices yet",
                    detail: "Pair Apple TV, iPhone, or iPad from the Devices tab."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(accountStore.devices.prefix(3)) { device in
                        HStack {
                            Image(systemName: device.platform == "tvos" ? "appletv.fill" : "iphone")
                                .foregroundStyle(Theme.accentBright)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.displayName).font(.subheadline.weight(.semibold))
                                Text(device.trustState.capitalized)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Circle()
                                .fill(device.revokedAt == nil ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                        }
                    }
                    Button("Manage Devices") { selection = .devices }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accentBright)
                }
            }
        }
    }

    private var recentActivity: some View {
        dashboardSection("Recent Activity", icon: "clock.arrow.circlepath") {
            EmptyDashboardState(
                icon: "clock",
                title: "Activity will appear here",
                detail: "GhostStream will show recent playback and cross-device progress without inventing history you have not created."
            )
        }
    }

    private func dashboardSection<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.white)
            content()
        }
        .padding(17)
        .background(Theme.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }
}

private struct EmptyDashboardState: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.accentBright)
                .frame(width: 38, height: 38)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
    }
}
