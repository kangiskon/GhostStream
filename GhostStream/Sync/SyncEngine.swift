import Foundation

@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published private(set) var syncCursor: Int

    private let api: GhostStreamAPIClient
    private let defaults: UserDefaults
    private weak var accountStore: AccountStore?

    private let cursorKey = "ghoststream.sync.cursor.v2"
    private let pendingSourcesKey = "ghoststream.sync.pendingSources.v2"
    private let pendingProgressKey = "ghoststream.sync.pendingProgress.v2"

    private var pendingSources: [CloudSourceProfile]
    private var pendingProgress: [PlaybackProgressRecord]

    init(
        api: GhostStreamAPIClient = GhostStreamAPIClient(),
        defaults: UserDefaults = .standard
    ) {
        self.api = api
        self.defaults = defaults
        syncCursor = defaults.integer(forKey: cursorKey)
        pendingSources = Self.decode([CloudSourceProfile].self, key: pendingSourcesKey, defaults: defaults) ?? []
        pendingProgress = Self.decode([PlaybackProgressRecord].self, key: pendingProgressKey, defaults: defaults) ?? []
    }

    func start(accountStore: AccountStore) {
        self.accountStore = accountStore
        guard accountStore.isSignedIn else { return }

        enqueueSourceProfiles(SourceMigrationCoordinator.shared.cloudProfiles())
        Task {
            await pull()
            await pushPending()
        }
    }

    func enqueueSourceProfiles(_ profiles: [CloudSourceProfile]) {
        for profile in profiles {
            pendingSources.removeAll { $0.sourceID == profile.sourceID }
            pendingSources.append(profile)
        }
        persistPending()
    }

    func enqueueProgress(_ record: PlaybackProgressRecord) {
        pendingProgress.removeAll { $0.id == record.id }
        pendingProgress.append(record)
        persistPending()
    }

    func pushPending() async {
        guard let accountStore, accountStore.isSignedIn else { return }
        guard !pendingSources.isEmpty || !pendingProgress.isEmpty else {
            accountStore.updateSyncState(.idle)
            return
        }

        accountStore.updateSyncState(.syncing)
        let sentSources = pendingSources
        let sentProgress = pendingProgress

        do {
            let token = try await accountStore.validAccessToken()
            let ack = try await push(sources: sentSources, progress: sentProgress, accessToken: token)
            commitPush(ack: ack, sentSources: sentSources, sentProgress: sentProgress)
            accountStore.updateSyncState(.idle)
        } catch {
            if let apiError = error as? APIError, apiError == .unauthorized {
                do {
                    let pair = try await accountStore.refreshSession()
                    let ack = try await push(sources: sentSources, progress: sentProgress, accessToken: pair.accessToken)
                    commitPush(ack: ack, sentSources: sentSources, sentProgress: sentProgress)
                    accountStore.updateSyncState(.idle)
                    return
                } catch {
                    await handle(error)
                }
            } else {
                await handle(error)
            }
        }
    }

    func pull() async {
        guard let accountStore, accountStore.isSignedIn else { return }
        accountStore.updateSyncState(.syncing)

        do {
            let token = try await accountStore.validAccessToken()
            let envelope: SyncEnvelopeDTO = try await api.send(
                path: "sync/pull?since=\(syncCursor)",
                accessToken: token
            )
            apply(envelope)
            accountStore.updateSyncState(.idle)
        } catch {
            if let apiError = error as? APIError, apiError == .unauthorized {
                do {
                    let pair = try await accountStore.refreshSession()
                    let envelope: SyncEnvelopeDTO = try await api.send(
                        path: "sync/pull?since=\(syncCursor)",
                        accessToken: pair.accessToken
                    )
                    apply(envelope)
                    accountStore.updateSyncState(.idle)
                    return
                } catch {
                    await handle(error)
                }
            } else {
                await handle(error)
            }
        }
    }

    func clearLocalState() {
        syncCursor = 0
        pendingSources.removeAll()
        pendingProgress.removeAll()
        defaults.removeObject(forKey: cursorKey)
        defaults.removeObject(forKey: pendingSourcesKey)
        defaults.removeObject(forKey: pendingProgressKey)
    }

    private func push(
        sources: [CloudSourceProfile],
        progress: [PlaybackProgressRecord],
        accessToken: String
    ) async throws -> SyncPushAck {
        try await api.send(
            path: "sync/push",
            body: SyncPushBody(sources: sources, progress: progress),
            accessToken: accessToken
        )
    }

    private func commitPush(
        ack: SyncPushAck,
        sentSources: [CloudSourceProfile],
        sentProgress: [PlaybackProgressRecord]
    ) {
        let sourceIDs = Set(sentSources.map(\.sourceID))
        let progressIDs = Set(sentProgress.map(\.id))
        pendingSources.removeAll { sourceIDs.contains($0.sourceID) }
        pendingProgress.removeAll { progressIDs.contains($0.id) }
        syncCursor = max(syncCursor, ack.cursor)
        defaults.set(syncCursor, forKey: cursorKey)
        persistPending()
    }

    private func apply(_ envelope: SyncEnvelopeDTO) {
        for event in envelope.events where event.entityType == "progress" && event.operation == "upsert" {
            if let record = progressRecord(from: event) {
                PlaybackProgressStore.shared.applyRemote(record)
            }
        }
        syncCursor = max(syncCursor, envelope.cursor)
        defaults.set(syncCursor, forKey: cursorKey)
    }

    private func progressRecord(from event: SyncEventDTO) -> PlaybackProgressRecord? {
        guard let sourceString = event.payload["source_id"]?.stringValue,
              let sourceID = UUID(uuidString: sourceString),
              let kindString = event.payload["content_kind"]?.stringValue,
              let kind = PlaybackContentKind(rawValue: kindString),
              let contentID = event.payload["content_id"]?.stringValue,
              let position = event.payload["position_seconds"]?.doubleValue,
              let duration = event.payload["duration_seconds"]?.doubleValue,
              let updatedString = event.payload["updated_at"]?.stringValue,
              let updatedAt = Self.isoDate(updatedString) else {
            return nil
        }
        return PlaybackProgressRecord(
            sourceID: sourceID,
            contentKind: kind,
            contentID: contentID,
            positionSeconds: max(0, position),
            durationSeconds: max(0, duration),
            completed: event.payload["completed"]?.boolValue ?? false,
            updatedAt: updatedAt
        )
    }

    private func handle(_ error: Error) async {
        if let apiError = error as? APIError, apiError == .accountDeleted {
            await GlobalDeletionCoordinator.shared.wipeAndSignOut(reason: .accountDeleted)
            return
        }
        accountStore?.updateSyncState(.failed(error.localizedDescription))
    }

    private func persistPending() {
        Self.encode(pendingSources, key: pendingSourcesKey, defaults: defaults)
        Self.encode(pendingProgress, key: pendingProgressKey, defaults: defaults)
    }

    private static func encode<T: Encodable>(_ value: T, key: String, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func isoDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}

private struct SyncPushBody: Codable {
    let sources: [CloudSourceProfile]
    let progress: [PlaybackProgressRecord]
}

private struct SyncPushAck: Codable {
    let cursor: Int
}

private extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}
