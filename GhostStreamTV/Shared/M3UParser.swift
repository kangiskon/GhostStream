import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Parses M3U / M3U8 playlists into `[Channel]`.
///
/// Supported syntax:
///   #EXTM3U
///   #EXTINF:-1 tvg-id="id" tvg-name="Name" tvg-logo="http://..." group-title="Group",Display Name
///   http://stream.url/path.ts
///
/// Lines beginning with #EXTVLCOPT (and any other comment/directive that is
/// not #EXTINF) are handled gracefully and do not break parsing.
enum M3UParser {

    /// Parse playlist text into channels.
    static func parse(_ text: String) -> [Channel] {
        var channels: [Channel] = []
        var pending: PendingEntry? = nil
        var autoIndex = 0

        // Normalize line endings and iterate.
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("#EXTINF") {
                pending = parseExtInf(line)
            } else if line.hasPrefix("#EXTVLCOPT") {
                // VLC option directive (e.g. #EXTVLCOPT:http-user-agent=...).
                // We ignore these but keep the pending entry intact.
                continue
            } else if line.hasPrefix("#") {
                // #EXTM3U, #EXTGRP, comments, or any other directive.
                if line.hasPrefix("#EXTGRP:"), pending != nil {
                    let grp = String(line.dropFirst("#EXTGRP:".count))
                        .trimmingCharacters(in: .whitespaces)
                    if pending?.group == nil || pending?.group?.isEmpty == true {
                        pending?.group = grp
                    }
                }
                continue
            } else {
                // A URL line. Attach to the pending #EXTINF if present,
                // otherwise create a bare channel from the URL alone.
                let url = line
                if let entry = pending {
                    autoIndex += 1
                    let id = entry.tvgId?.isEmpty == false
                        ? entry.tvgId!
                        : "m3u-\(autoIndex)"
                    let channel = Channel(
                        id: id,
                        name: entry.name.isEmpty ? deriveName(from: url) : entry.name,
                        url: url,
                        logo: entry.logo?.isEmpty == false ? entry.logo : nil,
                        group: entry.group?.isEmpty == false ? entry.group : nil,
                        tvgId: entry.tvgId?.isEmpty == false ? entry.tvgId : nil,
                        streamId: nil
                    )
                    channels.append(channel)
                    pending = nil
                } else {
                    autoIndex += 1
                    channels.append(Channel(
                        id: "m3u-\(autoIndex)",
                        name: deriveName(from: url),
                        url: url
                    ))
                }
            }
        }

        return channels
    }

    /// Fetch a remote playlist and parse it.
    static func parse(url: URL) async throws -> [Channel] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/x-mpegURL, application/vnd.apple.mpegurl, audio/mpegurl, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("GhostStream/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "M3UParser", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode) fetching playlist"])
        }
        guard !data.isEmpty else {
            throw NSError(domain: "M3UParser", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "The playlist URL returned no data."])
        }
        let text = String(decoding: data, as: UTF8.self)
        let channels = parse(text)
        guard !channels.isEmpty else {
            throw NSError(domain: "M3UParser", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "The URL responded, but no playable M3U entries were found."])
        }
        return channels
    }

    // MARK: - Private

    private struct PendingEntry {
        var name: String = ""
        var logo: String?
        var group: String?
        var tvgId: String?
        var tvgName: String?
    }

    /// Parse a single #EXTINF line.
    private static func parseExtInf(_ line: String) -> PendingEntry {
        var entry = PendingEntry()

        // Everything after the first comma (that is outside quotes) is the
        // display name. The attributes live between "#EXTINF:" and that comma.
        guard let commaIndex = indexOfDisplayNameComma(line) else {
            return entry
        }

        let attrsPart = String(line[line.index(line.startIndex, offsetBy: "#EXTINF:".count)..<commaIndex])
        let namePart = String(line[line.index(after: commaIndex)...])
            .trimmingCharacters(in: .whitespaces)

        entry.name = namePart

        let attrs = parseAttributes(attrsPart)
        entry.tvgId = attrs["tvg-id"]
        entry.tvgName = attrs["tvg-name"]
        entry.logo = attrs["tvg-logo"]
        entry.group = attrs["group-title"]

        if entry.name.isEmpty, let tvgName = entry.tvgName, !tvgName.isEmpty {
            entry.name = tvgName
        }

        return entry
    }

    /// Find the comma that separates attributes from the display name.
    /// Commas inside quoted attribute values must be ignored.
    private static func indexOfDisplayNameComma(_ line: String) -> String.Index? {
        var inQuotes = false
        var idx = line.startIndex
        while idx < line.endIndex {
            let ch = line[idx]
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                return idx
            }
            idx = line.index(after: idx)
        }
        return nil
    }

    /// Parse key="value" pairs from the attributes segment.
    private static func parseAttributes(_ segment: String) -> [String: String] {
        var result: [String: String] = [:]
        let chars = Array(segment)
        var i = 0
        let n = chars.count

        while i < n {
            // Skip until a key start (letters/digits).
            while i < n, !(chars[i].isLetter || chars[i].isNumber) {
                i += 1
            }
            var key = ""
            while i < n, chars[i] != "=", !chars[i].isWhitespace {
                key.append(chars[i])
                i += 1
            }
            // Skip whitespace before '='.
            while i < n, chars[i].isWhitespace { i += 1 }
            guard i < n, chars[i] == "=" else { continue }
            i += 1 // consume '='
            // Skip whitespace after '='.
            while i < n, chars[i].isWhitespace { i += 1 }

            var value = ""
            if i < n, chars[i] == "\"" {
                i += 1 // consume opening quote
                while i < n, chars[i] != "\"" {
                    value.append(chars[i])
                    i += 1
                }
                if i < n { i += 1 } // consume closing quote
            } else {
                while i < n, !chars[i].isWhitespace {
                    value.append(chars[i])
                    i += 1
                }
            }

            if !key.isEmpty {
                result[key.lowercased()] = value
            }
        }

        return result
    }

    /// Derive a readable name from a URL when no display name is provided.
    private static func deriveName(from url: String) -> String {
        if let last = URL(string: url)?.lastPathComponent, !last.isEmpty {
            return last
        }
        return url
    }
}
