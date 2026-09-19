import Foundation
import CryptoKit

private enum LibraryLoadError: LocalizedError {
    case allSectionsFailed(String)

    var errorDescription: String? {
        switch self {
        case .allSectionsFailed(let details):
            return "Connected to the provider, but GhostStream could not fetch Live TV, Movies, or Series.\n\(details)"
        }
    }
}

/// Loads and holds the current source's content (live channels, movies, series).
/// Everything is fetched at runtime from the user's source; nothing is bundled.
@MainActor
final class LibraryViewModel: ObservableObject {

    @Published var channels: [Channel] = []
    @Published var movies: [VODStream] = []
    @Published var series: [Series] = []

    @Published var liveCategories: [Category] = []
    @Published var movieCategories: [Category] = []
    @Published var seriesCategories: [Category] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var loadedSourceID: UUID?
    @Published private(set) var refreshNotice: String?
    // In-memory only: the actual endpoint used by successful provider authentication.
    @Published private(set) var resolvedProviderBaseURL: String?
    @Published private(set) var liveCategoryCounts: [String: Int] = [:]
    private var loadGeneration = 0
    private let snapshotCache = LibrarySnapshotCache.shared

    private func rebuildChannelCounts() {
        liveCategoryCounts = Dictionary(channels.compactMap { $0.group }.map { ($0, 1) },
                                        uniquingKeysWith: +)
    }

    func channelCount(in category: Category?) -> Int {
        guard let category else { return channels.count }
        let named = liveCategoryCounts[category.name, default: 0]
        return named + (category.name == category.id ? 0 : liveCategoryCounts[category.id, default: 0])
    }

    /// Display a protected, short-lived Xtream metadata snapshot first, then
    /// authenticate and refresh the provider's exact content. Callers still
    /// await the server response before accepting a new source as valid.
    func load(source: Source) async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        refreshNotice = nil
        resolvedProviderBaseURL = nil
        loadedSourceID = nil
        channels = []
        movies = []
        series = []
        liveCategories = []
        movieCategories = []
        seriesCategories = []
        liveCategoryCounts = [:]
        defer {
            if generation == loadGeneration { isLoading = false }
        }

        // The actor performs JSON decoding and disk I/O off the main actor.
        let cached = await snapshotCache.read(for: source)
        guard generation == loadGeneration, !Task.isCancelled else { return }
        if let cached {
            channels = cached.channels
            movies = cached.movies
            series = cached.series
            liveCategories = cached.liveCategories
            movieCategories = cached.movieCategories
            seriesCategories = cached.seriesCategories
            rebuildChannelCounts()
            refreshNotice = "Refreshing provider library…"
        }

        do {
            var cacheSnapshot = false
            switch source.kind {
            case .m3uURL:
                try await loadM3U(source: source, generation: generation)
            case .m3uText:
                try loadM3UText(source: source)
            case .xtream:
                cacheSnapshot = try await loadXtream(source: source, generation: generation)
            }
            guard generation == loadGeneration, !Task.isCancelled else { return }
            rebuildChannelCounts()
            loadedSourceID = source.id
            refreshNotice = nil

            // Saving full stream URLs would duplicate provider passwords from
            // Keychain into a plain JSON file. The cache actor stores only
            // sanitized metadata and reconstructs URLs from the live source.
            if cacheSnapshot {
                let channels = channels
                let movies = movies
                let series = series
                let liveCategories = liveCategories
                let movieCategories = movieCategories
                let seriesCategories = seriesCategories
                Task.detached(priority: .utility) {
                    await LibrarySnapshotCache.shared.store(
                        source: source, channels: channels, movies: movies, series: series,
                        liveCategories: liveCategories, movieCategories: movieCategories,
                        seriesCategories: seriesCategories
                    )
                }
            }
        } catch {
            guard generation == loadGeneration else { return }
            loadedSourceID = nil
            if cached == nil {
                errorMessage = error.localizedDescription
            } else {
                // Stale library remains browseable, but never counts as a
                // validated new provider login or a successful refresh.
                refreshNotice = "Offline library shown; provider refresh failed."
            }
        }
    }

    func reset() {
        loadGeneration += 1 // Discard late network responses from the old source.
        isLoading = false
        channels = []
        movies = []
        series = []
        liveCategories = []
        movieCategories = []
        seriesCategories = []
        liveCategoryCounts = [:]
        loadedSourceID = nil
        refreshNotice = nil
        resolvedProviderBaseURL = nil
        errorMessage = nil
    }

    // MARK: - M3U

    private func loadM3U(source: Source, generation: Int) async throws {
        guard let urlString = source.m3uURL, let url = URL(string: urlString) else {
            throw NSError(domain: "Library", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid M3U URL."])
        }
        let parsed = try await M3UParser.parse(url: url)
        try Task.checkCancellation()
        guard generation == loadGeneration else { throw CancellationError() }
        applyM3U(parsed)
    }

    private func loadM3UText(source: Source) throws {
        let parsed = M3UParser.parse(source.m3uText ?? "")
        guard !parsed.isEmpty else {
            throw NSError(domain: "Library", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "The playlist contains no playable entries."])
        }
        applyM3U(parsed)
    }

    private func applyM3U(_ parsed: [Channel]) {
        channels = parsed
        movies = []
        series = []
        // Derive live categories from group-title.
        let groups = Set(parsed.compactMap { $0.group })
        liveCategories = groups.sorted().map { Category(id: $0, name: $0) }
        movieCategories = []
        seriesCategories = []
    }

    // MARK: - Xtream

    private func loadXtream(source: Source, generation: Int) async throws -> Bool {
        guard let server = source.serverURL,
              let user = source.username,
              let pass = source.password else {
            throw NSError(domain: "Library", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Incomplete provider credentials."])
        }

        let discoveryClient = XtreamClient(serverURL: server, username: user, password: pass)
        let resolved = try await discoveryClient.authenticateResolved()
        guard generation == loadGeneration else { throw CancellationError() }
        resolvedProviderBaseURL = resolved.baseURL
        let client = XtreamClient(serverURL: resolved.baseURL, username: user, password: pass)

        // Fetch in stages instead of hitting the provider with six simultaneous
        // API calls. A number of Xtream panels throttle or time out under bursts.
        // Live loads first so the most useful content can appear as soon as possible.
        var notes: [String] = []

        let live = await Self.loadLive(client)
        try Task.checkCancellation()
        guard generation == loadGeneration else { throw CancellationError() }
        self.liveCategories = live.categories
        let liveCategoryNames = Dictionary(uniqueKeysWithValues: live.categories.map { ($0.id, $0.name) })
        self.channels = live.items.map { channel in
            var c = channel
            if let categoryId = channel.group, let name = liveCategoryNames[categoryId] {
                c.group = name
            }
            return c
        }
        if let note = live.note { notes.append("Live: \(note)") }

        let vod = await Self.loadVOD(client)
        try Task.checkCancellation()
        guard generation == loadGeneration else { throw CancellationError() }
        self.movieCategories = vod.categories
        self.movies = vod.items
        if let note = vod.note { notes.append("Movies: \(note)") }

        let ser = await Self.loadSeries(client)
        try Task.checkCancellation()
        guard generation == loadGeneration else { throw CancellationError() }
        self.seriesCategories = ser.categories
        self.series = ser.items
        if let note = ser.note { notes.append("Series: \(note)") }

        if channels.isEmpty && movies.isEmpty && series.isEmpty {
            let details = notes.isEmpty
                ? "The provider accepted the login but returned an empty media library."
                : notes.joined(separator: "\n")
            throw LibraryLoadError.allSectionsFailed(details)
        }

        self.errorMessage = nil
        return notes.isEmpty // Don't overwrite a good snapshot with partial outage data.
    }

    // MARK: - Resilient staged section loaders

    private struct LiveSection { var categories: [Category]; var items: [Channel]; var note: String? }
    private struct VODSection { var categories: [Category]; var items: [VODStream]; var note: String? }
    private struct SeriesSection { var categories: [Category]; var items: [Series]; var note: String? }

    nonisolated private static func loadLive(_ client: XtreamClient) async -> LiveSection {
        var categories: [Category] = []
        var items: [Channel] = []
        var notes: [String] = []

        do { categories = try await client.liveCategories() }
        catch { notes.append("categories failed: \(error.localizedDescription)") }

        do { items = try await client.liveStreams() }
        catch { notes.append("streams failed: \(error.localizedDescription)") }

        return LiveSection(categories: categories,
                           items: items,
                           note: notes.isEmpty ? nil : notes.joined(separator: "; "))
    }

    nonisolated private static func loadVOD(_ client: XtreamClient) async -> VODSection {
        var categories: [Category] = []
        var items: [VODStream] = []
        var notes: [String] = []

        do { categories = try await client.vodCategories() }
        catch { notes.append("categories failed: \(error.localizedDescription)") }

        do { items = try await client.vodStreams() }
        catch { notes.append("streams failed: \(error.localizedDescription)") }

        return VODSection(categories: categories,
                          items: items,
                          note: notes.isEmpty ? nil : notes.joined(separator: "; "))
    }

    nonisolated private static func loadSeries(_ client: XtreamClient) async -> SeriesSection {
        var categories: [Category] = []
        var items: [Series] = []
        var notes: [String] = []

        do { categories = try await client.seriesCategories() }
        catch { notes.append("categories failed: \(error.localizedDescription)") }

        do { items = try await client.series() }
        catch { notes.append("streams failed: \(error.localizedDescription)") }

        return SeriesSection(categories: categories,
                             items: items,
                             note: notes.isEmpty ? nil : notes.joined(separator: "; "))
    }

    // MARK: - Filtering helpers

    func channels(in category: Category?) -> [Channel] {
        guard let category = category else { return channels }
        return channels.filter { $0.group == category.name || $0.group == category.id }
    }

    func search(_ query: String) -> (channels: [Channel], movies: [VODStream], series: [Series]) {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return ([], [], []) }
        return (
            channels.filter { $0.name.lowercased().contains(q) },
            movies.filter { $0.name.lowercased().contains(q) },
            series.filter { $0.name.lowercased().contains(q) }
        )
    }
}

// MARK: - Protected, credential-free Xtream library snapshots (iOS only)

private struct LibrarySnapshot: Codable {
    var savedAt: Date
    var fingerprint: String
    var channels: [Channel]
    var movies: [VODStream]
    var series: [Series]
    var liveCategories: [Category]
    var movieCategories: [Category]
    var seriesCategories: [Category]
}

private actor LibrarySnapshotCache {
    static let shared = LibrarySnapshotCache()
    private let lifetime: TimeInterval = 7 * 24 * 60 * 60
    private let maxBytes = 32 * 1024 * 1024

    private func file(for source: Source) -> URL? {
        guard source.kind == .xtream,
              let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("GhostStreamLibrary", isDirectory: true)
            .appendingPathComponent(source.id.uuidString + ".json")
    }

    private func fingerprint(for source: Source) -> String? {
        // Includes the credential identity but stores only the SHA-256 digest.
        guard let bytes = try? JSONEncoder().encode(source) else { return nil }
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    func read(for source: Source) -> LibrarySnapshot? {
        guard let url = file(for: source), let signature = fingerprint(for: source),
              let bytes = try? Data(contentsOf: url), bytes.count <= maxBytes,
              var snapshot = try? JSONDecoder().decode(LibrarySnapshot.self, from: bytes),
              snapshot.fingerprint == signature,
              snapshot.savedAt <= Date(),
              Date().timeIntervalSince(snapshot.savedAt) < lifetime,
              let server = source.serverURL,
              let user = source.username,
              let pass = source.password else { return nil }

        // Rehydrate URLs in memory; never persist URLs containing Xtream credentials.
        let client = XtreamClient(serverURL: server, username: user, password: pass)
        snapshot.channels = snapshot.channels.map { item in
            var channel = item
            channel.url = item.streamId.map { client.liveStreamURL(id: $0) } ?? ""
            return channel
        }
        snapshot.movies = snapshot.movies.map { item in
            var movie = item
            movie.url = client.vodStreamURL(id: item.id, ext: item.containerExtension ?? "mp4")
            return movie
        }
        return snapshot
    }

    func store(source: Source, channels: [Channel], movies: [VODStream], series: [Series],
               liveCategories: [Category], movieCategories: [Category], seriesCategories: [Category]) {
        guard source.kind == .xtream, let url = file(for: source),
              let signature = fingerprint(for: source) else { return }

        // URLs, direct URLs and artwork URLs can all contain tokens or login
        // information. Do not put them in the on-disk snapshot.
        let safeChannels = channels.map { item -> Channel in
            var channel = item
            channel.url = ""
            channel.logo = nil
            return channel
        }
        let safeMovies = movies.map { item -> VODStream in
            var movie = item
            movie.url = nil
            movie.directSource = nil
            movie.icon = nil
            return movie
        }
        let safeSeries = series.map { item -> Series in
            var show = item
            show.cover = nil
            return show
        }
        let snapshot = LibrarySnapshot(
            savedAt: Date(), fingerprint: signature, channels: safeChannels,
            movies: safeMovies, series: safeSeries,
            liveCategories: liveCategories, movieCategories: movieCategories,
            seriesCategories: seriesCategories
        )
        guard let bytes = try? JSONEncoder().encode(snapshot), bytes.count <= maxBytes else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try bytes.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            var protected = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try protected.setResourceValues(values)
        } catch {
            // A cache must never prevent the actual provider from loading.
            try? FileManager.default.removeItem(at: url)
        }
    }
}
