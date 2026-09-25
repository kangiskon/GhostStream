import Foundation

@MainActor
final class DiagnosticHistoryStore: ObservableObject {
    static let shared = DiagnosticHistoryStore()

    @Published private(set) var snapshots: [DiagnosticSnapshot] = []

    private let defaults: UserDefaults
    private let storageKey = "ghoststream.diagnostic.history.v2"
    private let maxSnapshots = 120

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([DiagnosticSnapshot].self, from: data) {
            snapshots = decoded.sorted { $0.checkedAt > $1.checkedAt }
        }
    }

    func record(_ snapshot: DiagnosticSnapshot) {
        snapshots.removeAll { $0.id == snapshot.id }
        snapshots.insert(snapshot, at: 0)
        trimAndPersist()
    }

    func history(for sourceID: UUID) -> [DiagnosticSnapshot] {
        snapshots.filter { $0.sourceID == sourceID }
    }

    func latest(for sourceID: UUID) -> DiagnosticSnapshot? {
        history(for: sourceID).first
    }

    func applyRemote(_ dto: DiagnosticSnapshotDTO) {
        guard !snapshots.contains(where: {
            $0.sourceID == dto.sourceID &&
            abs($0.checkedAt.timeIntervalSince(dto.createdAt)) < 0.5
        }) else { return }

        let score = min(100, max(0, dto.healthScore))
        let level: HealthLevel = score >= 80 ? .stable : (score >= 45 ? .attention : .critical)
        let metrics = DiagnosticMetrics(
            responseTimeMs: dto.responseTimeMs,
            startupLatencyMs: dto.latencyMs,
            bitrateMbps: dto.bitrateMbps,
            width: dto.width,
            height: dto.height,
            videoCodec: dto.videoCodec,
            audioCodec: dto.audioCodec,
            container: dto.container,
            bufferingEvents: dto.bufferingEvents,
            compatibility: DiagnosticCompatibility(rawValue: dto.compatibility ?? "") ?? .unknown
        )
        let snapshot = DiagnosticSnapshot(
            sourceID: dto.sourceID,
            checkedAt: dto.createdAt,
            online: dto.errorCategory == nil,
            healthScore: score,
            healthLevel: level,
            metrics: metrics,
            errorCategory: dto.errorCategory.flatMap(DiagnosticErrorCategory.init(rawValue:)),
            statusExplanation: "Synced diagnostic summary from another trusted GhostStream device."
        )
        snapshots.append(snapshot)
        snapshots.sort { $0.checkedAt > $1.checkedAt }
        trimAndPersist()
    }

    func clearAll() {
        snapshots.removeAll()
        defaults.removeObject(forKey: storageKey)
    }

    private func trimAndPersist() {
        if snapshots.count > maxSnapshots {
            snapshots = Array(snapshots.prefix(maxSnapshots))
        }
        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
