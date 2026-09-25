import SwiftUI

struct TVSourceHealthView: View {
    @EnvironmentObject private var store: SourceStore

    @State private var snapshots: [TVDiagnosticSummaryDTO] = []
    @State private var loading = false
    @State private var errorMessage: String?

    private var latest: TVDiagnosticSummaryDTO? {
        snapshots.sorted { $0.createdAt > $1.createdAt }.first
    }

    var body: some View {
        ZStack {
            TVTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SOURCE HEALTH")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .tracking(3)
                            Text("Synced GhostStream diagnostics without provider credentials or raw source URLs")
                                .font(.headline)
                                .foregroundStyle(TVTheme.muted)
                        }
                        Spacer()
                        Button {
                            Task { await reload() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.headline.weight(.bold))
                                .padding(.horizontal, 24)
                                .frame(height: 56)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TVTheme.accent)
                    }

                    if store.activeSource == nil {
                        statusCard(
                            icon: "externaldrive.badge.questionmark",
                            title: "No source connected",
                            detail: "Connect one of your authorized sources to view its Source Health."
                        )
                    } else if loading && latest == nil {
                        ProgressView("Loading Source Health…")
                            .tint(TVTheme.accentBright)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if let latest {
                        healthPanel(latest)
                        historyPanel
                    } else if let errorMessage {
                        statusCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Health data unavailable",
                            detail: errorMessage
                        )
                    } else {
                        statusCard(
                            icon: "waveform.path.ecg.rectangle",
                            title: "No diagnostics yet",
                            detail: "Run Source Intelligence on iPhone or iPad. Sanitized results will sync here without sending your provider password or raw source URL."
                        )
                    }
                }
                .padding(.horizontal, 72)
                .padding(.vertical, 46)
            }
        }
        .task(id: store.activeSourceID) {
            await reload()
        }
    }

    private func healthPanel(_ item: TVDiagnosticSummaryDTO) -> some View {
        HStack(spacing: 34) {
            ZStack {
                Circle().stroke(TVTheme.border, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(item.healthScore, 0), 100)) / 100)
                    .stroke(healthColor(item.healthScore), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(item.healthScore)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                    Text("HEALTH SCORE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TVTheme.muted)
                }
            }
            .frame(width: 190, height: 190)

            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Label(item.errorCategory == nil ? "Online" : "Needs Attention",
                          systemImage: item.errorCategory == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.title3.bold())
                        .foregroundStyle(item.errorCategory == nil ? Color.green : Color.orange)
                    Spacer()
                    Text("Last Checked \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.headline)
                        .foregroundStyle(TVTheme.muted)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    metric("Response Time", milliseconds(item.responseTimeMs))
                    metric("Latency", milliseconds(item.latencyMs))
                    metric("Bitrate", item.bitrateMbps.map { String(format: "%.2f Mbps", $0) } ?? "Unknown")
                    metric("Resolution", resolution(item))
                    metric("Video Codec", item.videoCodec ?? "Unknown")
                    metric("Audio Codec", item.audioCodec ?? "Unknown")
                    metric("Container", item.container ?? "Unknown")
                    metric("Buffering", "\(item.bufferingEvents) events")
                    metric("Compatibility", item.compatibility?.capitalized ?? "Unknown")
                }
            }
        }
        .padding(30)
        .background(TVTheme.cardGradient, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(TVTheme.border, lineWidth: 1))
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RECENT HEALTH HISTORY")
                .font(.headline.weight(.bold))
                .tracking(2)

            ForEach(snapshots.prefix(8)) { item in
                HStack(spacing: 14) {
                    Circle()
                        .fill(healthColor(item.healthScore))
                        .frame(width: 10, height: 10)
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                    Spacer()
                    Text(item.deviceClass.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TVTheme.muted)
                    Text("\(item.healthScore)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(26)
        .background(TVTheme.card, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(TVTheme.border, lineWidth: 1))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(TVTheme.muted)
            Text(value)
                .font(.headline)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
    }

    private func statusCard(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 22) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(TVTheme.accentBright)
                .frame(width: 86, height: 86)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.title3.bold())
                Text(detail).font(.headline).foregroundStyle(TVTheme.muted)
            }
            Spacer()
        }
        .padding(28)
        .background(TVTheme.card, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(TVTheme.border, lineWidth: 1))
    }

    private func healthColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 45 { return .orange }
        return .red
    }

    private func milliseconds(_ value: Double?) -> String {
        guard let value else { return "Unknown" }
        return value >= 1000 ? String(format: "%.2f s", value / 1000) : String(format: "%.0f ms", value)
    }

    private func resolution(_ item: TVDiagnosticSummaryDTO) -> String {
        guard let width = item.width, let height = item.height else { return "Unknown" }
        return "\(width) × \(height)"
    }

    @MainActor
    private func reload() async {
        guard let sourceID = store.activeSourceID else {
            snapshots = []
            return
        }
        guard TVSessionVault.readRefreshToken() != nil else {
            errorMessage = "Pair this Apple TV with your GhostStream account to receive sanitized Source Health history."
            snapshots = []
            return
        }

        loading = true
        errorMessage = nil
        defer { loading = false }
        do {
            snapshots = try await TVSyncService.shared.fetchDiagnostics(sourceID: sourceID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
