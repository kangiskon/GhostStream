import Foundation

enum PlaybackContentKind: String, Codable {
    case vod
    case episode
}

struct PlaybackProgressRecord: Codable, Equatable, Identifiable {
    let sourceID: UUID
    let contentKind: PlaybackContentKind
    let contentID: String
    var title: String? = nil
    var seriesID: Int? = nil
    var positionSeconds: Double
    var durationSeconds: Double
    var completed: Bool
    var updatedAt: Date

    var id: String {
        "\(sourceID.uuidString)|\(contentKind.rawValue)|\(contentID)"
    }

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case contentKind = "content_kind"
        case contentID = "content_id"
        case title
        case seriesID = "series_id"
        case positionSeconds = "position_seconds"
        case durationSeconds = "duration_seconds"
        case completed
        case updatedAt = "updated_at"
    }
}

@MainActor
final class PlaybackProgressStore: ObservableObject {
    static let shared = PlaybackProgressStore()

    @Published private(set) var records: [PlaybackProgressRecord] = []

    private let defaults: UserDefaults
    private let storageKey = "ghoststream.playbackProgress.v2"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func record(
        sourceID: UUID,
        contentKind: PlaybackContentKind,
        contentID: String,
        title: String? = nil,
        seriesID: Int? = nil,
        positionSeconds: Double,
        durationSeconds: Double,
        completed: Bool,
        updatedAt: Date = Date()
    ) -> PlaybackProgressRecord {
        let safeDuration = max(0, durationSeconds.isFinite ? durationSeconds : 0)
        let safePosition = max(0, positionSeconds.isFinite ? positionSeconds : 0)
        let boundedPosition = safeDuration > 0 ? min(safePosition, safeDuration) : safePosition
        let record = PlaybackProgressRecord(
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
        applyRemote(record)
        return record
    }

    func applyRemote(_ incoming: PlaybackProgressRecord) {
        if let index = records.firstIndex(where: { $0.id == incoming.id }) {
            guard records[index].updatedAt < incoming.updatedAt else { return }
            records[index] = incoming
        } else {
            records.append(incoming)
        }
        records.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    func clear(sourceID: UUID, contentKind: PlaybackContentKind, contentID: String) {
        let key = "\(sourceID.uuidString)|\(contentKind.rawValue)|\(contentID)"
        records.removeAll { $0.id == key }
        persist()
    }

    func clearAll() {
        records.removeAll()
        defaults.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PlaybackProgressRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
