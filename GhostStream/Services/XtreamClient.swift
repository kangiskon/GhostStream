import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Async Xtream Codes API client.
///
/// All data is fetched from a user-provided server; nothing is bundled.
/// The `player_api.php` endpoint is used with these actions:
///   get_live_categories, get_live_streams,
///   get_vod_categories, get_vod_streams,
///   get_series_categories, get_series, get_series_info,
///   and auth (no action parameter -> returns user_info / server_info).
struct XtreamClient {

    let baseURL: String
    let username: String
    let password: String
    private let session: URLSession
    private let candidateBases: [String]

    init(serverURL: String, username: String, password: String, session: URLSession = .shared) {
        let candidates = XtreamClient.candidateBaseURLs(serverURL)
        self.baseURL = candidates.first ?? XtreamClient.normalize(serverURL)
        self.candidateBases = candidates.isEmpty ? [self.baseURL] : candidates
        self.username = username
        self.password = password
        self.session = session
    }

    // MARK: - URL normalization

    /// Normalize common Xtream server inputs to the server origin/base path.
    /// Users sometimes paste player_api.php/get.php URLs instead of just host:port.
    static func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            // Prefer a secure connection when the user omits the scheme.
            // Legacy HTTP providers still work when the user explicitly enters http://.
            s = "https://" + s
        }

        if var c = URLComponents(string: s) {
            c.query = nil
            c.fragment = nil
            let lowerPath = c.path.lowercased()
            for endpoint in ["/player_api.php", "/get.php", "/xmltv.php"] {
                if let r = lowerPath.range(of: endpoint) {
                    c.path = String(c.path[..<r.lowerBound])
                    break
                }
            }
            if let rebuilt = c.url?.absoluteString { s = rebuilt }
        }

        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    /// Build a small set of safe API-base candidates for providers that return
    /// 404 because the saved URL points at a portal path, uses the wrong scheme,
    /// or includes player_api.php/get.php itself. Credentials are never included.
    static func candidateBaseURLs(_ raw: String) -> [String] {
        let primary = normalize(raw)
        guard !primary.isEmpty else { return [] }

        var values: [String] = []
        func appendUnique(_ value: String?) {
            guard var value = value, !value.isEmpty else { return }
            while value.hasSuffix("/") { value.removeLast() }
            if !values.contains(value) { values.append(value) }
        }

        func originOnly(_ value: String) -> String? {
            guard var c = URLComponents(string: value), c.host != nil else { return nil }
            c.path = ""
            c.query = nil
            c.fragment = nil
            return c.url?.absoluteString
        }

        func alternateScheme(_ value: String) -> String? {
            guard var c = URLComponents(string: value), let scheme = c.scheme?.lowercased() else { return nil }
            if scheme == "https" { c.scheme = "http" }
            else if scheme == "http" { c.scheme = "https" }
            else { return nil }
            return c.url?.absoluteString
        }

        // Preserve a legitimate provider sub-path first, then try the host root.
        appendUnique(primary)
        appendUnique(originOnly(primary))

        // A surprising number of provider panels are configured on only one of
        // HTTP/HTTPS. Try the alternate transport only after the entered URL form.
        if let alternate = alternateScheme(primary) {
            appendUnique(alternate)
            appendUnique(originOnly(alternate))
        }

        return values
    }

    // MARK: - Endpoint building

    private func playerAPIURL(base: String, action: String?, extra: [String: String] = [:]) -> URL? {
        var components = URLComponents(string: base + "/player_api.php")
        var items = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        if let action = action {
            items.append(URLQueryItem(name: "action", value: action))
        }
        for (k, v) in extra {
            items.append(URLQueryItem(name: k, value: v))
        }
        components?.queryItems = items
        return components?.url
    }

    // MARK: - Networking helper

    private func fetchAtBase<T: Decodable>(_ type: T.Type,
                                            base: String,
                                            action: String?,
                                            extra: [String: String] = [:]) async throws -> T {
        guard let url = playerAPIURL(base: base, action: action, extra: extra) else {
            throw XtreamError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("GhostStream/1.0", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw XtreamError.timedOut(base)
            case .cannotFindHost, .dnsLookupFailed:
                throw XtreamError.hostNotFound(base)
            case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                throw XtreamError.connectionFailed(base)
            default:
                throw XtreamError.network(urlError.localizedDescription)
            }
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw XtreamError.http(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw XtreamError.decoding(error)
        }
    }

    private func canTryAnotherBase(after error: Error) -> Bool {
        guard let error = error as? XtreamError else { return false }
        switch error {
        case .http(404), .timedOut, .hostNotFound, .connectionFailed:
            return true
        default:
            return false
        }
    }

    /// Fetch while discovering which sanitized provider base actually hosts
    /// player_api.php. The successful base is returned so generated stream URLs
    /// use the same endpoint instead of the original 404 address.
    private func fetchResolved<T: Decodable>(_ type: T.Type,
                                              action: String?,
                                              extra: [String: String] = [:]) async throws -> (value: T, base: String) {
        var lastError: Error = XtreamError.invalidURL
        for (index, candidate) in candidateBases.enumerated() {
            do {
                let value = try await fetchAtBase(type, base: candidate, action: action, extra: extra)
                return (value, candidate)
            } catch {
                lastError = error
                let hasMore = index + 1 < candidateBases.count
                if !hasMore || !canTryAnotherBase(after: error) { throw error }
            }
        }
        throw lastError
    }

    private func fetch<T: Decodable>(_ type: T.Type, action: String?, extra: [String: String] = [:]) async throws -> T {
        try await fetchResolved(type, action: action, extra: extra).value
    }

    // MARK: - Authentication

    /// Validate credentials. Returns the auth payload on success.
    @discardableResult
    func authenticate() async throws -> XtreamAuth {
        try await authenticateResolved().auth
    }

    /// Authenticate and report the working API base. This lets callers reuse the
    /// discovered host/scheme/path for the rest of the provider session.
    func authenticateResolved() async throws -> (auth: XtreamAuth, baseURL: String) {
        let result = try await fetchResolved(XtreamAuth.self, action: nil)
        guard result.value.userInfo?.auth == 1 else {
            throw XtreamError.authFailed
        }
        return (result.value, result.base)
    }

    // MARK: - Live

    func liveCategories() async throws -> [Category] {
        let raw = try await fetch([XtreamCategory].self, action: "get_live_categories")
        return raw.map { Category(id: $0.categoryId, name: $0.categoryName) }
    }

    func liveStreams(categoryId: String? = nil) async throws -> [Channel] {
        var extra: [String: String] = [:]
        if let categoryId = categoryId { extra["category_id"] = categoryId }
        let result = try await fetchResolved([XtreamLiveStream].self, action: "get_live_streams", extra: extra)
        return result.value.map { s in
            Channel(
                id: String(s.streamId),
                name: s.name,
                url: liveStreamURL(base: result.base, id: s.streamId),
                logo: s.streamIcon,
                group: s.categoryId,
                tvgId: s.epgChannelId,
                streamId: s.streamId
            )
        }
    }

    // MARK: - VOD (Movies)

    func vodCategories() async throws -> [Category] {
        let raw = try await fetch([XtreamCategory].self, action: "get_vod_categories")
        return raw.map { Category(id: $0.categoryId, name: $0.categoryName) }
    }

    func vodStreams(categoryId: String? = nil) async throws -> [VODStream] {
        var extra: [String: String] = [:]
        if let categoryId = categoryId { extra["category_id"] = categoryId }
        let result = try await fetchResolved([XtreamVODStream].self, action: "get_vod_streams", extra: extra)
        return result.value.map { s in
            let ext = normalizedContainerExtension(s.containerExtension, fallback: "mp4")
            let fallback = vodStreamURL(base: result.base, id: s.streamId, ext: ext)
            let direct = resolveAssetURL(s.directSource, base: result.base)
            return VODStream(
                id: s.streamId,
                name: s.name,
                icon: resolveAssetURL(s.bestArtwork, base: result.base),
                categoryId: s.categoryId,
                containerExtension: ext,
                directSource: direct,
                url: preferredPlaybackURL(directSource: direct, fallback: fallback, base: result.base)
            )
        }
    }

    // MARK: - Series

    func seriesCategories() async throws -> [Category] {
        let raw = try await fetch([XtreamCategory].self, action: "get_series_categories")
        return raw.map { Category(id: $0.categoryId, name: $0.categoryName) }
    }

    func series(categoryId: String? = nil) async throws -> [Series] {
        var extra: [String: String] = [:]
        if let categoryId = categoryId { extra["category_id"] = categoryId }
        let result = try await fetchResolved([XtreamSeries].self, action: "get_series", extra: extra)
        return result.value.map { s in
            Series(
                id: s.seriesId,
                name: s.name,
                cover: resolveAssetURL(s.bestArtwork, base: result.base),
                categoryId: s.categoryId,
                plot: s.plot
            )
        }
    }

    /// Fetch full series info (seasons -> episodes) and flatten to `[Episode]`.
    func seriesInfo(seriesId: Int) async throws -> [Episode] {
        // Some user-supplied providers temporarily return 404 from their
        // series-info endpoint while a panel is updating. Retry that read-only
        // request once, without retrying unrelated errors indefinitely.
        let result: (value: XtreamSeriesInfo, base: String)
        do {
            result = try await fetchResolved(XtreamSeriesInfo.self,
                                             action: "get_series_info",
                                             extra: ["series_id": String(seriesId)])
        } catch XtreamError.http(404) {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 350_000_000)
            try Task.checkCancellation()
            result = try await fetchResolved(XtreamSeriesInfo.self,
                                             action: "get_series_info",
                                             extra: ["series_id": String(seriesId)])
        }
        let info = result.value
        var episodes: [Episode] = []
        // `episodes` may arrive as a Map (season -> list) or a flat List.
        // XtreamSeriesInfo normalizes both into a season-keyed dictionary.
        for (seasonKey, list) in info.episodesBySeason {
            let mapSeason = Int(seasonKey)
            for ep in list {
                // Prefer the episode's own season field; fall back to the map
                // key; finally default to season 1.
                let season = ep.season ?? mapSeason ?? 1
                // Only fall back to a container extension when truly absent.
                let ext = normalizedContainerExtension(ep.containerExtension, fallback: "mp4")
                let fallback = seriesStreamURL(base: result.base, id: ep.id, ext: ext)
                let direct = resolveAssetURL(ep.directSource, base: result.base)
                episodes.append(Episode(
                    id: ep.id,
                    title: ep.title ?? "Episode \(ep.episodeNum ?? 0)",
                    season: season,
                    episodeNum: ep.episodeNum ?? 0,
                    containerExtension: ext,
                    directSource: direct,
                    url: preferredPlaybackURL(directSource: direct, fallback: fallback, base: result.base)
                ))
            }
        }
        episodes.sort { ($0.season, $0.episodeNum) < ($1.season, $1.episodeNum) }
        return episodes
    }

    // MARK: - Provider URL cleanup

    /// Normalizes artwork/direct-source URLs returned by inconsistent Xtream panels.
    /// Supports absolute URLs, protocol-relative URLs, provider-relative paths and
    /// unescaped spaces without changing already-valid signed URLs.
    private func resolveAssetURL(_ raw: String?, base: String) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }

        let lowered = value.lowercased()
        if lowered == "null" || lowered == "n/a" || lowered == "none" { return nil }

        if value.hasPrefix("//"), let scheme = URLComponents(string: base)?.scheme {
            value = scheme + ":" + value
        }

        func validString(_ candidate: String) -> String? {
            guard let url = URL(string: candidate), url.scheme != nil else { return nil }
            return url.absoluteString
        }

        if let valid = validString(value) { return valid }
        let escaped = value.replacingOccurrences(of: " ", with: "%20")
        if let valid = validString(escaped) { return valid }

        guard let baseURL = URL(string: base + "/") else { return nil }
        if let relative = URL(string: escaped, relativeTo: baseURL)?.absoluteURL {
            return relative.absoluteString
        }
        return nil
    }

    private func normalizedContainerExtension(_ raw: String?, fallback: String) -> String {
        let ext = raw?.trimmingCharacters(in: CharacterSet(charactersIn: ". ")) ?? ""
        return ext.isEmpty ? fallback : ext.lowercased()
    }

    /// Prefer a provider-supplied direct source when it is usable. Many VOD
    /// panels proxy movies/episodes through a different host than player_api.php.
    private func preferredPlaybackURL(directSource: String?, fallback: String, base: String) -> String {
        resolveAssetURL(directSource, base: base) ?? fallback
    }


    // MARK: - Provider EPG (exact Live stream)

    /// Fetch the provider's short EPG for one exact Xtream live stream ID.
    /// This avoids XMLTV/channel-name matching and asks player_api.php for the
    /// guide attached directly to the stream the user selected.
    func shortEPG(streamId: Int, limit: Int = 8) async throws -> [EPGProgramme] {
        let response = try await fetch(
            XtreamShortEPGResponse.self,
            action: "get_short_epg",
            extra: ["stream_id": String(streamId), "limit": String(max(1, limit))]
        )
        return response.epgListings.compactMap { listing in
            guard let start = listing.startDate,
                  let stop = listing.stopDate,
                  stop > start else { return nil }
            let decodedTitle = Self.decodeEPGText(listing.title) ?? "Programme"
            let decodedDescription = Self.decodeEPGText(listing.description)
            return EPGProgramme(
                channelId: String(streamId),
                title: decodedTitle,
                desc: decodedDescription,
                start: start,
                stop: stop
            )
        }
        .sorted { $0.start < $1.start }
    }

    private static func decodeEPGText(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let data = Data(base64Encoded: trimmed),
           let decoded = String(data: data, encoding: .utf8) {
            let clean = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { return clean }
        }
        return trimmed
    }

    // MARK: - Stream URL builders

    private func liveStreamURL(base: String, id: Int, extension ext: String = "ts") -> String {
        "\(base)/live/\(username)/\(password)/\(id).\(ext)"
    }

    func liveStreamURL(id: Int, extension ext: String = "ts") -> String {
        liveStreamURL(base: baseURL, id: id, extension: ext)
    }

    private func vodStreamURL(base: String, id: Int, ext: String) -> String {
        "\(base)/movie/\(username)/\(password)/\(id).\(ext)"
    }

    func vodStreamURL(id: Int, ext: String) -> String {
        vodStreamURL(base: baseURL, id: id, ext: ext)
    }

    private func seriesStreamURL(base: String, id: String, ext: String) -> String {
        "\(base)/series/\(username)/\(password)/\(id).\(ext)"
    }

    func seriesStreamURL(id: String, ext: String) -> String {
        seriesStreamURL(base: baseURL, id: id, ext: ext)
    }

    /// Derived XMLTV EPG endpoint for this account.
    func xmltvURL() -> URL? {
        var components = URLComponents(string: baseURL + "/xmltv.php")
        components?.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        return components?.url
    }
}

// MARK: - Errors

enum XtreamError: LocalizedError {
    case invalidURL
    case http(Int)
    case decoding(Error)
    case authFailed
    case timedOut(String)
    case hostNotFound(String)
    case connectionFailed(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL."
        case .http(let code):
            if code == 404 {
                return "Provider API returned HTTP 404. Enter the provider server base URL (for example https://host:port), not a customer portal or web-player page. GhostStream also tried the sanitized server root and alternate HTTP/HTTPS scheme."
            }
            return "Server returned HTTP \(code)."
        case .decoding(let e): return "Failed to decode server response: \(e.localizedDescription)"
        case .authFailed: return "Authentication failed. Check your username and password."
        case .timedOut(let base): return "The provider did not respond at \(base). Check the server address, http/https scheme, and port."
        case .hostNotFound(let base): return "Could not find the provider host at \(base). Check the server address."
        case .connectionFailed(let base): return "Could not connect to \(base). Check the server address, port, and network connection."
        case .network(let message): return "Network error: \(message)"
        }
    }
}

// MARK: - Codable wire models

struct XtreamAuth: Decodable {
    struct UserInfo: Decodable {
        let auth: Int?
        let status: String?
        let expDate: String?

        enum CodingKeys: String, CodingKey {
            case auth
            case status
            case expDate = "exp_date"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            auth = c.flexibleInt(.auth)
            status = c.flexibleString(.status)
            expDate = c.flexibleString(.expDate)
        }
    }
    struct ServerInfo: Decodable {
        let url: String?
        let port: String?
        let httpsPort: String?

        enum CodingKeys: String, CodingKey {
            case url
            case port
            case httpsPort = "https_port"
        }
    }
    let userInfo: UserInfo?
    let serverInfo: ServerInfo?

    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case serverInfo = "server_info"
    }
}

// MARK: - Tolerant decoding helpers
//
// Xtream panels are wildly inconsistent: the same numeric field can arrive as
// a JSON number, a quoted string, or a float (e.g. "stream_id":"1234" vs 1234,
// category_id, series_id, num, rating, episode_num, episode id). Strict Codable
// throws on the unexpected shape, which previously blanked Movies and Series
// while Live happened to decode. These helpers coerce Int-or-String-or-Double.

extension KeyedDecodingContainer {
    /// Decode an integer from Int, String, or Double; nil if missing/blank.
    func flexibleInt(_ key: Key) -> Int? {
        if let i = try? decode(Int.self, forKey: key) { return i }
        if let d = try? decode(Double.self, forKey: key) { return Int(d) }
        if let s = try? decode(String.self, forKey: key) {
            let t = s.trimmingCharacters(in: .whitespaces)
            if let i = Int(t) { return i }
            if let d = Double(t) { return Int(d) }
        }
        return nil
    }

    /// Decode a String from String, Int, or Double; nil if missing/blank.
    func flexibleString(_ key: Key) -> String? {
        if let s = try? decode(String.self, forKey: key) {
            return s.isEmpty ? nil : s
        }
        if let i = try? decode(Int.self, forKey: key) { return String(i) }
        if let d = try? decode(Double.self, forKey: key) {
            // Emit "5" not "5.0" when the value is integral.
            return d == d.rounded() ? String(Int(d)) : String(d)
        }
        return nil
    }
}

// MARK: - Codable wire models (tolerant)

struct XtreamCategory: Decodable {
    let categoryId: String
    let categoryName: String

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categoryId = c.flexibleString(.categoryId) ?? ""
        categoryName = c.flexibleString(.categoryName) ?? ""
    }
}

struct XtreamLiveStream: Decodable {
    let streamId: Int
    let name: String
    let streamIcon: String?
    let epgChannelId: String?
    let categoryId: String?
    let num: Int?

    enum CodingKeys: String, CodingKey {
        case streamId = "stream_id"
        case name
        case streamIcon = "stream_icon"
        case epgChannelId = "epg_channel_id"
        case categoryId = "category_id"
        case num
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        streamId = c.flexibleInt(.streamId) ?? 0
        name = c.flexibleString(.name) ?? ""
        streamIcon = c.flexibleString(.streamIcon)
        epgChannelId = c.flexibleString(.epgChannelId)
        categoryId = c.flexibleString(.categoryId)
        num = c.flexibleInt(.num)
    }
}

struct XtreamVODStream: Decodable {
    let streamId: Int
    let name: String
    let streamIcon: String?
    let movieImage: String?
    let cover: String?
    let coverBig: String?
    let directSource: String?
    let categoryId: String?
    let containerExtension: String?
    let num: Int?
    let rating: String?

    var bestArtwork: String? { streamIcon ?? movieImage ?? coverBig ?? cover }

    enum CodingKeys: String, CodingKey {
        case streamId = "stream_id"
        case name
        case streamIcon = "stream_icon"
        case movieImage = "movie_image"
        case cover
        case coverBig = "cover_big"
        case directSource = "direct_source"
        case categoryId = "category_id"
        case containerExtension = "container_extension"
        case num
        case rating
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        streamId = c.flexibleInt(.streamId) ?? 0
        name = c.flexibleString(.name) ?? ""
        streamIcon = c.flexibleString(.streamIcon)
        movieImage = c.flexibleString(.movieImage)
        cover = c.flexibleString(.cover)
        coverBig = c.flexibleString(.coverBig)
        directSource = c.flexibleString(.directSource)
        categoryId = c.flexibleString(.categoryId)
        containerExtension = c.flexibleString(.containerExtension)
        num = c.flexibleInt(.num)
        rating = c.flexibleString(.rating)
    }
}

struct XtreamSeries: Decodable {
    let seriesId: Int
    let name: String
    let cover: String?
    let coverBig: String?
    let streamIcon: String?
    let categoryId: String?
    let plot: String?
    let num: Int?
    let rating: String?

    var bestArtwork: String? { cover ?? coverBig ?? streamIcon }

    enum CodingKeys: String, CodingKey {
        case seriesId = "series_id"
        case name
        case cover
        case coverBig = "cover_big"
        case streamIcon = "stream_icon"
        case categoryId = "category_id"
        case plot
        case num
        case rating
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seriesId = c.flexibleInt(.seriesId) ?? 0
        name = c.flexibleString(.name) ?? ""
        cover = c.flexibleString(.cover)
        coverBig = c.flexibleString(.coverBig)
        streamIcon = c.flexibleString(.streamIcon)
        categoryId = c.flexibleString(.categoryId)
        plot = c.flexibleString(.plot)
        num = c.flexibleInt(.num)
        rating = c.flexibleString(.rating)
    }
}



struct XtreamShortEPGResponse: Decodable {
    let epgListings: [XtreamEPGListing]

    enum CodingKeys: String, CodingKey {
        case epgListings = "epg_listings"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        epgListings = (try? c.decode([XtreamEPGListing].self, forKey: .epgListings)) ?? []
    }
}

struct XtreamEPGListing: Decodable {
    let title: String?
    let description: String?
    let start: String?
    let end: String?
    let startTimestamp: String?
    let stopTimestamp: String?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case start
        case end
        case startTimestamp = "start_timestamp"
        case stopTimestamp = "stop_timestamp"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.flexibleString(.title)
        description = c.flexibleString(.description)
        start = c.flexibleString(.start)
        end = c.flexibleString(.end)
        startTimestamp = c.flexibleString(.startTimestamp)
        stopTimestamp = c.flexibleString(.stopTimestamp)
    }

    var startDate: Date? { Self.date(timestamp: startTimestamp, fallback: start) }
    var stopDate: Date? { Self.date(timestamp: stopTimestamp, fallback: end) }

    private static func date(timestamp: String?, fallback: String?) -> Date? {
        if let timestamp,
           let seconds = Double(timestamp.trimmingCharacters(in: .whitespacesAndNewlines)),
           seconds > 0 {
            return Date(timeIntervalSince1970: seconds)
        }

        guard let fallback else { return nil }
        let value = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd'T'HH:mm:ssZ"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let parsed = formatter.date(from: value) { return parsed }
        }
        return nil
    }
}

struct XtreamSeriesInfo: Decodable {
    struct EpisodeEntry: Decodable {
        let id: String
        let title: String?
        let episodeNum: Int?
        let containerExtension: String?
        let directSource: String?
        let season: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case episodeNum = "episode_num"
            case containerExtension = "container_extension"
            case directSource = "direct_source"
            case season
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // id may be Int or String -> always coerce to String.
            id = c.flexibleString(.id) ?? ""
            title = c.flexibleString(.title)
            episodeNum = c.flexibleInt(.episodeNum)
            containerExtension = c.flexibleString(.containerExtension)
            directSource = c.flexibleString(.directSource)
            season = c.flexibleInt(.season)
        }
    }

    /// `episodes` may arrive as a Map (season -> list) OR occasionally a flat
    /// List. This container tolerates either and normalizes to a dictionary.
    private enum EpisodesContainer: Decodable {
        case map([String: [EpisodeEntry]])
        case list([EpisodeEntry])

        init(from decoder: Decoder) throws {
            if let dict = try? decoder.singleValueContainer()
                .decode([String: [EpisodeEntry]].self) {
                self = .map(dict)
            } else if let arr = try? decoder.singleValueContainer()
                .decode([EpisodeEntry].self) {
                self = .list(arr)
            } else {
                self = .map([:])
            }
        }
    }

    private let episodesContainer: EpisodesContainer?

    enum CodingKeys: String, CodingKey {
        case episodes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        episodesContainer = try? c.decode(EpisodesContainer.self, forKey: .episodes)
    }

    /// Normalized season-keyed episodes. A flat list is grouped by each
    /// episode's `season` field (default "1").
    var episodesBySeason: [String: [EpisodeEntry]] {
        switch episodesContainer {
        case .map(let dict):
            return dict
        case .list(let arr):
            var out: [String: [EpisodeEntry]] = [:]
            for ep in arr {
                let key = String(ep.season ?? 1)
                out[key, default: []].append(ep)
            }
            return out
        case .none:
            return [:]
        }
    }
}
