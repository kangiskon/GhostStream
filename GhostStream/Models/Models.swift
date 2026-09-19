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

struct Channel: Codable, Identifiable, Hashable {
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

struct Category: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

// MARK: - VOD (Movies)

struct VODStream: Codable, Identifiable, Hashable {
    let id: Int             // stream_id
    var name: String
    var icon: String?
    var categoryId: String?
    var containerExtension: String?  // e.g. "mp4", "mkv"
    var directSource: String? = nil  // provider supplied direct playback URL when available
    var url: String?        // resolved playback url
}

// MARK: - Series

struct Series: Codable, Identifiable, Hashable {
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
