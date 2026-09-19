import Foundation

// MARK: - Source

/// A user-provided media source: playlist URL/text or provider login.
/// No channels, media, subscriptions, playlists, or credentials are bundled.
/// Every value is supplied by the user at runtime.
struct Source: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case m3uURL
        case m3uText
        case xtream
    }

    var id: UUID
    var name: String
    var kind: Kind

    // M3U
    var m3uURL: String?
    var m3uText: String?

    // Xtream
    var serverURL: String?
    var username: String?
    var password: String?

    // Optional user-supplied EPG URL (XMLTV). If nil and kind == .xtream,
    // the client derives {base}/xmltv.php?username=&password=.
    var epgURL: String?

    init(id: UUID = UUID(),
         name: String,
         kind: Kind,
         m3uURL: String? = nil,
         m3uText: String? = nil,
         serverURL: String? = nil,
         username: String? = nil,
         password: String? = nil,
         epgURL: String? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.m3uURL = m3uURL
        self.m3uText = m3uText
        self.serverURL = serverURL
        self.username = username
        self.password = password
        self.epgURL = epgURL
    }
}

// MARK: - Channel (Live)

struct Channel: Identifiable, Hashable {
    let id: String          // stable id (tvg-id or synthesized)
    var name: String
    var url: String
    var logo: String?
    var group: String?      // group-title / category name
    var tvgId: String?
    var streamId: Int?      // Xtream numeric stream id (nil for M3U)

    init(id: String,
         name: String,
         url: String,
         logo: String? = nil,
         group: String? = nil,
         tvgId: String? = nil,
         streamId: Int? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.logo = logo
        self.group = group
        self.tvgId = tvgId
        self.streamId = streamId
    }
}

// MARK: - Category

struct Category: Identifiable, Hashable {
    let id: String
    let name: String
}

/// Fast provider-native category indexing used by tvOS.
/// Category IDs/names come directly from the user's provider and are never
/// regrouped into GhostStream-defined genres.
struct ProviderCategoryIndex {
    static func liveBuckets(items: [Channel]) -> [String: [Channel]] {
        bucket(items: items) { $0.group }
    }

    static func movieBuckets(items: [VODStream]) -> [String: [VODStream]] {
        bucket(items: items) { $0.categoryId }
    }

    static func seriesBuckets(items: [Series]) -> [String: [Series]] {
        bucket(items: items) { $0.categoryId }
    }

    static func nonEmptyCategories(_ categories: [Category], counts: [String: Int]) -> [Category] {
        var seen = Set<String>()
        return categories.compactMap { category in
            let id = category.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !name.isEmpty, (counts[id] ?? 0) > 0, seen.insert(id).inserted else { return nil }
            return Category(id: id, name: name)
        }
    }

    private static func bucket<T>(items: [T], categoryID: (T) -> String?) -> [String: [T]] {
        var result: [String: [T]] = [:]
        result.reserveCapacity(64)
        for item in items {
            guard let raw = categoryID(item)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { continue }
            result[raw, default: []].append(item)
        }
        return result
    }
}

// MARK: - Standard media genres

/// Stable, user-facing genre buckets used by the Apple TV library. Provider
/// category IDs remain untouched underneath; this layer only cleans up how
/// movies and series are presented.
enum StandardMediaGenre: String, CaseIterable, Identifiable, Hashable {
    case actionAdventure
    case comedy
    case drama
    case horror
    case kidsFamily
    case documentary
    case sciFiFantasy
    case thrillerMystery
    case romance
    case crime
    case animation
    case reality
    case sports
    case music
    case western
    case warHistory
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .actionAdventure: return "Action & Adventure"
        case .comedy: return "Comedy"
        case .drama: return "Drama"
        case .horror: return "Horror"
        case .kidsFamily: return "Kids & Family"
        case .documentary: return "Documentary"
        case .sciFiFantasy: return "Sci-Fi & Fantasy"
        case .thrillerMystery: return "Thriller & Mystery"
        case .romance: return "Romance"
        case .crime: return "Crime"
        case .animation: return "Animation"
        case .reality: return "Reality"
        case .sports: return "Sports"
        case .music: return "Music"
        case .western: return "Western"
        case .warHistory: return "War & History"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .actionAdventure: return "bolt.fill"
        case .comedy: return "face.smiling.fill"
        case .drama: return "theatermasks.fill"
        case .horror: return "moon.stars.fill"
        case .kidsFamily: return "figure.2.and.child.holdinghands"
        case .documentary: return "doc.text.magnifyingglass"
        case .sciFiFantasy: return "sparkles"
        case .thrillerMystery: return "magnifyingglass"
        case .romance: return "heart.fill"
        case .crime: return "shield.fill"
        case .animation: return "wand.and.stars"
        case .reality: return "person.3.fill"
        case .sports: return "sportscourt.fill"
        case .music: return "music.note"
        case .western: return "sun.max.fill"
        case .warHistory: return "clock.arrow.circlepath"
        case .other: return "square.grid.2x2.fill"
        }
    }

    /// Convert inconsistent provider categories into stable GhostStream genres.
    /// Multiple matches are intentionally returned so mixed provider buckets
    /// such as "Action Comedy" appear in both useful genre views.
    static func classify(categoryName: String?, title: String, plot: String?) -> [StandardMediaGenre] {
        let category = normalize(categoryName ?? "")
        let titleText = normalize(title)
        let plotText = normalize(plot ?? "")
        let combined = "\(category) \(titleText) \(plotText)"

        var matches: [StandardMediaGenre] = []

        func add(_ genre: StandardMediaGenre, keywords: [String]) {
            guard keywords.contains(where: { containsKeyword($0, in: combined) }) else { return }
            if !matches.contains(genre) { matches.append(genre) }
        }

        add(.actionAdventure, keywords: ["action", "adventure", "superhero", "martial arts", "kung fu"])
        add(.comedy, keywords: ["comedy", "comedies", "sitcom", "stand up", "standup"])
        add(.drama, keywords: ["drama", "dramatic"])
        add(.horror, keywords: ["horror", "slasher", "zombie", "haunted", "paranormal"])
        add(.kidsFamily, keywords: ["kids", "kid", "family", "children", "childrens", "child"])
        add(.documentary, keywords: ["documentary", "documentaries", "docuseries", "docu series", "biography"])
        add(.sciFiFantasy, keywords: ["sci fi", "scifi", "science fiction", "fantasy", "supernatural", "space opera"])
        add(.thrillerMystery, keywords: ["thriller", "mystery", "mysteries", "suspense", "detective"])
        add(.romance, keywords: ["romance", "romantic", "love story"])
        add(.crime, keywords: ["crime", "criminal", "gangster", "mafia", "murder", "police", "detective"])
        add(.animation, keywords: ["animation", "animated", "anime", "cartoon"])
        add(.reality, keywords: ["reality", "game show", "talent show", "competition show"])
        add(.sports, keywords: ["sport", "sports", "football", "soccer", "hockey", "basketball", "baseball", "wrestling", "mma", "boxing", "ufc"])
        add(.music, keywords: ["music", "musical", "concert", "concerts"])
        add(.western, keywords: ["western", "cowboy", "cowboys"])
        add(.warHistory, keywords: ["war", "history", "historical", "military", "world war"])

        // Generic provider labels (NEW RELEASES, US SERIES, 4K, etc.) do not
        // become fake genres. Anything with no semantic match lands in Other.
        return matches.isEmpty ? [.other] : matches
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "|", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    private static func containsKeyword(_ keyword: String, in text: String) -> Bool {
        let normalizedKeyword = normalize(keyword)
        guard !normalizedKeyword.isEmpty else { return false }
        if normalizedKeyword.contains(" ") { return text.contains(normalizedKeyword) }
        return text.split(separator: " ").contains(Substring(normalizedKeyword))
    }
}

// MARK: - VOD (Movies)

struct VODStream: Identifiable, Hashable {
    let id: Int             // stream_id
    var name: String
    var icon: String?
    var categoryId: String?
    var containerExtension: String?  // e.g. "mp4", "mkv"
    var directSource: String? = nil  // provider supplied direct playback URL when available
    var url: String?        // resolved playback url
}

// MARK: - Series

struct Series: Identifiable, Hashable {
    let id: Int             // series_id
    var name: String
    var cover: String?
    var categoryId: String?
    var plot: String?
}

struct Episode: Identifiable, Hashable {
    let id: String          // episode id (string in Xtream)
    var title: String
    var season: Int
    var episodeNum: Int
    var containerExtension: String?
    var directSource: String? = nil  // provider supplied direct playback URL when available
    var image: String? = nil         // provider episode thumbnail when available
    var duration: String? = nil
    var plot: String? = nil
    var url: String?
}

// MARK: - EPG

struct EPGProgramme: Identifiable, Hashable {
    var id: String { channelId + "|" + String(start.timeIntervalSince1970) }
    let channelId: String
    let title: String
    let desc: String?
    let start: Date
    let stop: Date
}

// MARK: - Apple TV progressive media paging

/// Keeps very large provider libraries responsive on tvOS by rendering a
/// bounded window of cards and expanding it as the viewer approaches the end.
enum TVMediaPaging {
    static let initialLimit = 60
    static let increment = 36

    static func nextLimit(current: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        let normalizedCurrent = max(0, min(current, total))
        guard normalizedCurrent < total else { return total }
        return min(total, max(initialLimit, normalizedCurrent + increment))
    }
}
