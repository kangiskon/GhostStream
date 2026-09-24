import Foundation

struct ActivityEntry: Codable, Equatable, Identifiable {
    let sourceID: UUID
    let contentKind: String
    let contentID: String
    let title: String
    let deviceName: String?
    let updatedAt: Date

    var id: String {
        "\(sourceID.uuidString)|\(contentKind)|\(contentID)"
    }
}

@MainActor
final class ActivityStore: ObservableObject {
    static let shared = ActivityStore()

    @Published private(set) var entries: [ActivityEntry] = []

    private let defaults: UserDefaults
    private let storageKey = "ghoststream.activity.v2"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func record(_ entry: ActivityEntry) {
        entries.removeAll { $0.id == entry.id }
        entries.insert(entry, at: 0)
        if entries.count > 100 {
            entries = Array(entries.prefix(100))
        }
        persist()
    }

    func clear(id: String) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        entries.removeAll()
        defaults.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
