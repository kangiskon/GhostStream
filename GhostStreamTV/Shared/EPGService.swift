import Foundation

/// Fetches and caches the provider's exact per-stream Xtream EPG.
/// Guide data is keyed by the provider's `stream_id`, so no channel-name/ID
/// guessing is needed for Xtream Live channels.
@MainActor
final class EPGService: ObservableObject {

    @Published private(set) var programmes: [String: [EPGProgramme]] = [:]
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private var activeSourceID: UUID?
    private var loadingStreamIDs = Set<Int>()
    private var loadedStreamIDs = Set<Int>()

    /// Called when the active source changes. This no longer downloads a global
    /// guide; individual visible Live streams load their own provider EPG.
    func load(for source: Source) async {
        prepare(for: source)
    }

    func prepare(for source: Source) {
        guard activeSourceID != source.id else { return }
        activeSourceID = source.id
        programmes = [:]
        loadingStreamIDs = []
        loadedStreamIDs = []
        lastError = nil
    }

    /// Load guide data for one exact Live stream from Xtream's short-EPG API.
    /// Calls are cached so scrolling does not repeatedly hit the provider.
    func ensureProviderEPG(for channel: Channel, source: Source, limit: Int = 8) async {
        guard let streamId = channel.streamId else { return }
        await ensureProviderEPG(streamId: streamId, source: source, limit: limit)
    }

    func ensureProviderEPG(streamId: Int, source: Source, limit: Int = 8) async {
        prepare(for: source)
        guard source.kind == .xtream,
              let server = source.serverURL,
              let user = source.username,
              let pass = source.password else { return }

        guard !loadedStreamIDs.contains(streamId),
              !loadingStreamIDs.contains(streamId) else { return }

        loadingStreamIDs.insert(streamId)
        isLoading = true
        defer {
            loadingStreamIDs.remove(streamId)
            isLoading = !loadingStreamIDs.isEmpty
        }

        do {
            let client = XtreamClient(serverURL: server, username: user, password: pass)
            let guide = try await client.shortEPG(streamId: streamId, limit: limit)
            programmes[String(streamId)] = guide
            loadedStreamIDs.insert(streamId)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func nowPlaying(channel: Channel, at date: Date = Date()) -> EPGProgramme? {
        guard let streamId = channel.streamId else { return nil }
        return nowPlaying(streamId: streamId, at: date)
    }

    func upcoming(channel: Channel, after date: Date = Date(), limit: Int = 10) -> [EPGProgramme] {
        guard let streamId = channel.streamId else { return [] }
        return upcoming(streamId: streamId, after: date, limit: limit)
    }

    func nowPlaying(streamId: Int, at date: Date = Date()) -> EPGProgramme? {
        guard let list = programmes[String(streamId)] else { return nil }
        return list.first { $0.start <= date && date < $0.stop }
    }

    func upcoming(streamId: Int, after date: Date = Date(), limit: Int = 10) -> [EPGProgramme] {
        guard let list = programmes[String(streamId)] else { return [] }
        return Array(list.filter { $0.start > date }.prefix(limit))
    }

    /// String-based convenience used by the Live player overlay.
    func nowPlaying(channelId: String, at date: Date = Date()) -> EPGProgramme? {
        guard let streamId = Int(channelId) else { return nil }
        return nowPlaying(streamId: streamId, at: date)
    }

    func upcoming(channelId: String, after date: Date = Date(), limit: Int = 10) -> [EPGProgramme] {
        guard let streamId = Int(channelId) else { return [] }
        return upcoming(streamId: streamId, after: date, limit: limit)
    }

    func clear() {
        programmes = [:]
        activeSourceID = nil
        loadingStreamIDs = []
        loadedStreamIDs = []
        lastError = nil
        isLoading = false
    }
}
