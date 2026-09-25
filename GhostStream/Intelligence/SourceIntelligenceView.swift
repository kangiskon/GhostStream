import SwiftUI

struct SourceIntelligenceView: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var accountStore: AccountStore
    @StateObject private var historyStore = DiagnosticHistoryStore.shared

    @State private var running = false
    @State private var latest: DiagnosticSnapshot?
    @State private var errorMessage: String?

    private let diagnostics = SourceDiagnosticsService()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Theme.background2, Theme.background, .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if let source = store.activeSource {
                            sourceCard(source)

                            if let snapshot = latest ?? historyStore.latest(for: source.id) {
                                SourceHealthDetailView(snapshot: snapshot)
                                issues(snapshot)
                                recommendations(snapshot)
                                DiagnosticHistoryView(snapshots: historyStore.history(for: source.id))
                            } else {
                                emptyState
                            }
                        } else {
                            noSource
                        }

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: store.activeSourceID) { newValue in
            latest = newValue.flatMap { historyStore.latest(for: $0) }
            errorMessage = nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SOURCE INTELLIGENCE")
                .font(.system(size: 27, weight: .black, design: .rounded))
                .tracking(2)
            Text("Health, compatibility, and playback diagnostics calculated on this device.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }

    private func sourceCard(_ source: Source) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform.path.ecg.rectangle.fill")
                .font(.title)
                .foregroundStyle(Theme.accentBright)
                .frame(width: 58, height: 58)
                .background(Theme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 17))

            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.headline)
                Text(source.kind == .xtream ? "Provider Login" : "Playlist Source")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            Button {
                Task { await run(source) }
            } label: {
                if running {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 112)
                } else {
                    Label("Run Diagnostics", systemImage: "stethoscope")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(running)
        }
        .padding(17)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accentBright)
            Text("No health check yet")
                .font(.headline)
            Text("Run Diagnostics to measure source response, playback compatibility, latency, and media details.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }

    private var noSource: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 42))
                .foregroundStyle(Theme.accentBright)
            Text("Connect a source first")
                .font(.headline)
            Text("Source Intelligence runs only against a source you added to GhostStream.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func issues(_ snapshot: DiagnosticSnapshot) -> some View {
        if !snapshot.issues.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Diagnostics", systemImage: "exclamationmark.bubble.fill")
                    .font(.headline)
                ForEach(snapshot.issues) { issue in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(issue.title).font(.subheadline.weight(.bold))
                        Text(issue.detail).font(.caption).foregroundStyle(Theme.muted)
                    }
                }
            }
            .padding(18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
        }
    }

    private func recommendations(_ snapshot: DiagnosticSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recommendations", systemImage: "lightbulb.fill")
                .font(.headline)
            if snapshot.recommendations.isEmpty {
                Text("No corrective action is currently available.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(snapshot.recommendations) { recommendation in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.title).font(.subheadline.weight(.bold))
                        Text(recommendation.detail).font(.caption).foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }

    @MainActor
    private func run(_ source: Source) async {
        running = true
        errorMessage = nil
        defer { running = false }

        let snapshot = await diagnostics.diagnose(source: source)
        latest = snapshot
        historyStore.record(snapshot)

        if accountStore.isSignedIn {
            let sanitized = DiagnosticSanitizer.sanitize(snapshot)
            SyncEngine.shared.enqueueDiagnostic(sanitized)
            await SyncEngine.shared.pushPending()
        }
    }
}
