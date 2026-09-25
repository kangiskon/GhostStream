import SwiftUI

struct SourceHealthDetailView: View {
    let snapshot: DiagnosticSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 22) {
                healthRing

                VStack(alignment: .leading, spacing: 6) {
                    Text("Health Score")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(Theme.muted)
                    Text(statusTitle)
                        .font(.title2.weight(.bold))
                    Label(snapshot.online ? "Online" : "Offline", systemImage: snapshot.online ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(snapshot.online ? Color.green : Color.red)
                    Text("Last Checked (snapshot.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
            }

            Text(snapshot.statusExplanation)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metric("Response Time", value: milliseconds(snapshot.metrics.responseTimeMs))
                metric("Latency", value: milliseconds(snapshot.metrics.startupLatencyMs))
                metric("Bitrate", value: bitrate(snapshot.metrics.bitrateMbps))
                metric("Resolution", value: resolution)
                metric("Video Codec", value: snapshot.metrics.videoCodec ?? "Unknown")
                metric("Audio Codec", value: snapshot.metrics.audioCodec ?? "Unknown")
                metric("Container", value: snapshot.metrics.container ?? "Unknown")
                metric("Buffering", value: "(snapshot.metrics.bufferingEvents) events")
            }
        }
        .padding(18)
        .background(Theme.cardGradient, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.border, lineWidth: 1))
    }

    private var healthRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.border, lineWidth: 10)
            Circle()
                .trim(from: 0, to: CGFloat(snapshot.healthScore) / 100)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("(snapshot.healthScore)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                Text("/ 100")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(width: 108, height: 108)
    }

    private var statusTitle: String {
        switch snapshot.healthLevel {
        case .stable: return "Stable"
        case .attention: return "Needs Attention"
        case .critical: return "Critical"
        }
    }

    private var ringColor: Color {
        switch snapshot.healthLevel {
        case .stable: return .green
        case .attention: return .orange
        case .critical: return .red
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }

    private func milliseconds(_ value: Double?) -> String {
        guard let value else { return "Unknown" }
        if value >= 1_000 { return String(format: "%.2f s", value / 1_000) }
        return String(format: "%.0f ms", value)
    }

    private func bitrate(_ value: Double?) -> String {
        guard let value else { return "Unknown" }
        return String(format: "%.2f Mbps", value)
    }

    private var resolution: String {
        guard let width = snapshot.metrics.width,
              let height = snapshot.metrics.height,
              width > 0, height > 0 else { return "Unknown" }
        return "(width) × (height)"
    }
}
