import Charts
import SwiftUI

struct DiagnosticHistoryView: View {
    let snapshots: [DiagnosticSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("History", systemImage: "chart.xyaxis.line")
                .font(.headline)

            if snapshots.isEmpty {
                Text("Run Diagnostics to build a source health history.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 14)
            } else {
                Chart(Array(snapshots.prefix(20).reversed())) { item in
                    LineMark(
                        x: .value("Checked", item.checkedAt),
                        y: .value("Health", item.healthScore)
                    )
                    PointMark(
                        x: .value("Checked", item.checkedAt),
                        y: .value("Health", item.healthScore)
                    )
                }
                .chartYScale(domain: 0...100)
                .frame(height: 180)

                ForEach(snapshots.prefix(5)) { item in
                    HStack {
                        Circle()
                            .fill(color(for: item.healthLevel))
                            .frame(width: 8, height: 8)
                        Text(item.checkedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                        Spacer()
                        Text("(item.healthScore)")
                            .font(.caption.weight(.bold).monospacedDigit())
                        Text(item.online ? "Online" : "Offline")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }

    private func color(for level: HealthLevel) -> Color {
        switch level {
        case .stable: return .green
        case .attention: return .orange
        case .critical: return .red
        }
    }
}
