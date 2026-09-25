import Foundation

enum TVPlaybackContentKind: String, Codable {
    case vod
    case episode
}

struct TVPlaybackProgressRecord: Codable, Equatable, Identifiable {
    let sourceID: UUID
    let contentKind: TVPlaybackContentKind
    let contentID: String
    var title: String?
    var seriesID: Int?
    var positionSeconds: Double
    var durationSeconds: Double
    var completed: Bool
    var updatedAt: Date

    var id: String {
        "\(sourceID.uuidString)|\(contentKind.rawValue)|\(contentID)"
    }

    enum CodingKeys: String, CodingKey {
        case title, completed
        case sourceID = "source_id"
        case contentKind = "content_kind"
        case contentID = "content_id"
        case seriesID = "series_id"
        case positionSeconds = "position_seconds"
        case durationSeconds = "duration_seconds"
        case updatedAt = "updated_at"
    }
}

@MainActor
final class TVPlaybackProgressStore: ObservableObject {
    static let shared = TVPlaybackProgressStore()

    @Published private(set) var records: [TVPlaybackProgressRecord] = []

    private let defaults: UserDefaults
    private let storageKey = "ghoststream.tv.playbackProgress.v2"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func record(
        sourceID: UUID,
        contentKind: TVPlaybackContentKind,
        contentID: String,
        title: String?,
        seriesID: Int?,
        positionSeconds: Double,
        durationSeconds: Double,
        completed: Bool,
        updatedAt: Date = Date()
    ) -> TVPlaybackProgressRecord {
        let safeDuration = durationSeconds.isFinite ? max(0, durationSeconds) : 0
        let safePosition = positionSeconds.isFinite ? max(0, positionSeconds) : 0
        let boundedPosition = safeDuration > 0 ? min(safePosition, safeDuration) : safePosition

        let item = TVPlaybackProgressRecord(
            sourceID: sourceID,
            contentKind: contentKind,
            contentID: contentID,
            title: title,
            seriesID: seriesID,
            positionSeconds: boundedPosition,
            durationSeconds: safeDuration,
            completed: completed,
            updatedAt: updatedAt
        )
        applyRemote(item)
        return item
    }

    func applyRemote(_ incoming: TVPlaybackProgressRecord) {
        if let index = records.firstIndex(where: { $0.id == incoming.id }) {
            guard records[index].updatedAt < incoming.updatedAt else { return }
            records[index] = incoming
        } else {
            records.append(incoming)
        }
        records.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    func active(limit: Int = 8) -> [TVPlaybackProgressRecord] {
        Array(records.filter {
            !$0.completed &&
            $0.durationSeconds > 30 &&
            $0.positionSeconds > 10 &&
            ($0.positionSeconds / max($0.durationSeconds, 1)) < 0.95
        }.prefix(limit))
    }

    func clearAll() {
        records.removeAll()
        defaults.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TVPlaybackProgressRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
