import Foundation

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

    // Provider-native category indexes. Keys are the provider's category_id
    // values (or M3U group-title for playlist sources). These are built once
    // when data arrives, so category switching is an O(1) dictionary lookup.
    @Published private(set) var liveCategoryBuckets: [String: [Channel]] = [:]
    @Published private(set) var movieCategoryBuckets: [String: [VODStream]] = [:]
    @Published private(set) var seriesCategoryBuckets: [String: [Series]] = [:]
    @Published private(set) var movieCategoryNamesByID: [String: String] = [:]
    @Published private(set) var seriesCategoryNamesByID: [String: String] = [:]

    // Legacy standard-genre indexes are retained for source compatibility but
    // tvOS presentation now uses the provider's real category system.
    // reclassifies thousands of titles during a SwiftUI body update.
    @Published private(set) var movieGenreBuckets: [StandardMediaGenre: [VODStream]] = [:]
    @Published private(set) var seriesGenreBuckets: [StandardMediaGenre: [Series]] = [:]
    @Published private(set) var movieGenresByID: [Int: [StandardMediaGenre]] = [:]
    @Published private(set) var seriesGenresByID: [Int: [StandardMediaGenre]] = [:]

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var loadedSourceID: UUID?

    /// Load content for the given source. Safe to call repeatedly; it reloads.
    func load(source: Source) async {
        isLoading = true
        errorMessage = nil
        loadedSourceID = nil

        // Never leave stale content on screen while a different/retried source loads.
        channels = []
        movies = []
        series = []
        liveCategories = []
        movieCategories = []
        seriesCategories = []
        liveCategoryBuckets = [:]
        movieCategoryBuckets = [:]
        seriesCategoryBuckets = [:]
        movieCategoryNamesByID = [:]
        seriesCategoryNamesByID = [:]
        movieGenreBuckets = [:]
        seriesGenreBuckets = [:]
        movieGenresByID = [:]
        seriesGenresByID = [:]

        defer { isLoading = false }

        do {
            switch source.kind {
            case .m3uURL:
                try await loadM3U(source: source)
            case .m3uText:
                try loadM3UText(source: source)
            case .xtream:
                try await loadXtream(source: source)
            }
            loadedSourceID = source.id
        } catch {
            // A failed request must never be marked as loaded. Otherwise selecting
            // the same source again will skip the fetch entirely.
            loadedSourceID = nil
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        channels = []
        movies = []
        series = []
        liveCategories = []
        movieCategories = []
        seriesCategories = []
        liveCategoryBuckets = [:]
        movieCategoryBuckets = [:]
        seriesCategoryBuckets = [:]
        movieCategoryNamesByID = [:]
        seriesCategoryNamesByID = [:]
        movieGenreBuckets = [:]
        seriesGenreBuckets = [:]
        movieGenresByID = [:]
        seriesGenresByID = [:]
        loadedSourceID = nil
        errorMessage = nil
    }

    // MARK: - M3U

    private func loadM3U(source: Source) async throws {
        guard let urlString = source.m3uURL, let url = URL(string: urlString) else {
            throw NSError(domain: "Library", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid M3U URL."])
        }
        let parsed = try await M3UParser.parse(url: url)
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
        // M3U has no Xtream category API, so group-title is the provider's
        // category system. Preserve first-seen order instead of re-grouping.
        var seenGroups = Set<String>()
        liveCategories = parsed.compactMap { channel in
            guard let raw = channel.group?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty, seenGroups.insert(raw).inserted else { return nil }
            return Category(id: raw, name: raw)
        }
        liveCategoryBuckets = ProviderCategoryIndex.liveBuckets(items: parsed)
        liveCategories = ProviderCategoryIndex.nonEmptyCategories(
            liveCategories, counts: liveCategoryBuckets.mapValues { $0.count }
        )
        movieCategories = []
        seriesCategories = []
        movieCategoryBuckets = [:]
        seriesCategoryBuckets = [:]
        movieCategoryNamesByID = [:]
        seriesCategoryNamesByID = [:]
        movieGenreBuckets = [:]
        seriesGenreBuckets = [:]
        movieGenresByID = [:]
        seriesGenresByID = [:]
    }

    // MARK: - Xtream

    private func loadXtream(source: Source) async throws {
        guard let server = source.serverURL,
              let user = source.username,
              let pass = source.password else {
            throw NSError(domain: "Library", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Incomplete provider credentials."])
        }

        let discoveryClient = XtreamClient(serverURL: server, username: user, password: pass)
        let resolved = try await discoveryClient.authenticateResolved()
        let client = XtreamClient(serverURL: resolved.baseURL, username: user, password: pass)

        // Fetch in stages instead of hitting the provider with six simultaneous
        // API calls. A number of Xtream panels throttle or time out under bursts.
        // Live loads first so the most useful content can appear as soon as possible.
        var notes: [String] = []

        let live = await Self.loadLive(client)
        let rawLiveBuckets = ProviderCategoryIndex.liveBuckets(items: live.items)
        self.liveCategoryBuckets = rawLiveBuckets
        self.liveCategories = ProviderCategoryIndex.nonEmptyCategories(
            live.categories, counts: rawLiveBuckets.mapValues { $0.count }
        )
        let liveCategoryNames = Dictionary(live.categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        self.channels = live.items.map { channel in
            var c = channel
            if let categoryId = channel.group, let name = liveCategoryNames[categoryId] {
                c.group = name
            }
            return c
        }
        if let note = live.note { notes.append("Live: \(note)") }

        let vod = await Self.loadVOD(client)
        let rawMovieBuckets = ProviderCategoryIndex.movieBuckets(items: vod.items)
        self.movieCategoryBuckets = rawMovieBuckets
        self.movieCategories = ProviderCategoryIndex.nonEmptyCategories(
            vod.categories, counts: rawMovieBuckets.mapValues { $0.count }
        )
        self.movieCategoryNamesByID = Dictionary(vod.categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        self.movies = vod.items
        if let note = vod.note { notes.append("Movies: \(note)") }

        let ser = await Self.loadSeries(client)
        let rawSeriesBuckets = ProviderCategoryIndex.seriesBuckets(items: ser.items)
        self.seriesCategoryBuckets = rawSeriesBuckets
        self.seriesCategories = ProviderCategoryIndex.nonEmptyCategories(
            ser.categories, counts: rawSeriesBuckets.mapValues { $0.count }
        )
        self.seriesCategoryNamesByID = Dictionary(ser.categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        self.series = ser.items
        if let note = ser.note { notes.append("Series: \(note)") }

        // tvOS now presents the provider's native category system directly.
        // Keep legacy genre state empty so large libraries are not classified a
        // second time in the background.
        self.movieGenreBuckets = [:]
        self.movieGenresByID = [:]
        self.seriesGenreBuckets = [:]
        self.seriesGenresByID = [:]

        if channels.isEmpty && movies.isEmpty && series.isEmpty {
            let details = notes.isEmpty
                ? "The provider accepted the login but returned an empty media library."
                : notes.joined(separator: "\n")
            throw LibraryLoadError.allSectionsFailed(details)
        }

        self.errorMessage = nil
    }

    // MARK: - Resilient staged section loaders

    private struct LiveSection {
        var categories: [Category]
        var items: [Channel]
        var note: String?
    }

    private struct VODSection {
        var categories: [Category]
        var items: [VODStream]
        var note: String?
    }

    private struct SeriesSection {
        var categories: [Category]
        var items: [Series]
        var note: String?
    }

    private struct MovieGenreIndex {
        var buckets: [StandardMediaGenre: [VODStream]]
        var genresByID: [Int: [StandardMediaGenre]]
    }

    private struct SeriesGenreIndex {
        var buckets: [StandardMediaGenre: [Series]]
        var genresByID: [Int: [StandardMediaGenre]]
    }

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

        return VODSection(
            categories: categories,
            items: items,
            note: notes.isEmpty ? nil : notes.joined(separator: "; ")
        )
    }

    nonisolated private static func loadSeries(_ client: XtreamClient) async -> SeriesSection {
        var categories: [Category] = []
        var items: [Series] = []
        var notes: [String] = []

        do { categories = try await client.seriesCategories() }
        catch { notes.append("categories failed: \(error.localizedDescription)") }

        do { items = try await client.series() }
        catch { notes.append("streams failed: \(error.localizedDescription)") }

        return SeriesSection(
            categories: categories,
            items: items,
            note: notes.isEmpty ? nil : notes.joined(separator: "; ")
        )
    }

    /// CPU-heavy classification runs on the generic executor, not the tvOS main
    /// actor, and periodically yields so very large libraries stay cooperative.
    nonisolated private static func buildMovieGenreIndex(
        categories: [Category],
        items: [VODStream]
    ) async -> MovieGenreIndex {
        let categoryNames = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        var buckets: [StandardMediaGenre: [VODStream]] = [:]
        var genresByID: [Int: [StandardMediaGenre]] = [:]

        for (offset, movie) in items.enumerated() {
            let categoryName = movie.categoryId.flatMap { categoryNames[$0] }
            let genres = StandardMediaGenre.classify(
                categoryName: categoryName,
                title: movie.name,
                plot: nil
            )
            genresByID[movie.id] = genres
            for genre in genres {
                buckets[genre, default: []].append(movie)
            }
            if offset > 0 && offset % 500 == 0 { await Task.yield() }
        }

        return MovieGenreIndex(buckets: buckets, genresByID: genresByID)
    }

    nonisolated private static func buildSeriesGenreIndex(
        categories: [Category],
        items: [Series]
    ) async -> SeriesGenreIndex {
        let categoryNames = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        var buckets: [StandardMediaGenre: [Series]] = [:]
        var genresByID: [Int: [StandardMediaGenre]] = [:]

        for (offset, show) in items.enumerated() {
            let categoryName = show.categoryId.flatMap { categoryNames[$0] }
            let genres = StandardMediaGenre.classify(
                categoryName: categoryName,
                title: show.name,
                plot: show.plot
            )
            genresByID[show.id] = genres
            for genre in genres {
                buckets[genre, default: []].append(show)
            }
            if offset > 0 && offset % 500 == 0 { await Task.yield() }
        }

        return SeriesGenreIndex(buckets: buckets, genresByID: genresByID)
    }

    // MARK: - Filtering helpers

    func channels(in category: Category?) -> [Channel] {
        guard let category else { return channels }
        return liveCategoryBuckets[category.id] ?? []
    }

    func movies(in category: Category?) -> [VODStream] {
        guard let category else { return movies }
        return movieCategoryBuckets[category.id] ?? []
    }

    func shows(in category: Category?) -> [Series] {
        guard let category else { return series }
        return seriesCategoryBuckets[category.id] ?? []
    }

    func liveCount(for category: Category) -> Int {
        liveCategoryBuckets[category.id]?.count ?? 0
    }

    func movieCount(for category: Category) -> Int {
        movieCategoryBuckets[category.id]?.count ?? 0
    }

    func seriesCount(for category: Category) -> Int {
        seriesCategoryBuckets[category.id]?.count ?? 0
    }

    func movieCategoryName(for categoryID: String?) -> String? {
        guard let categoryID else { return nil }
        return movieCategoryNamesByID[categoryID]
    }

    func seriesCategoryName(for categoryID: String?) -> String? {
        guard let categoryID else { return nil }
        return seriesCategoryNamesByID[categoryID]
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
