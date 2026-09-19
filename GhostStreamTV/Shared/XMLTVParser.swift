import Foundation
#if canImport(Compression)
import Compression
#endif

/// Streaming (SAX) XMLTV parser.
///
/// Parses `<channel id="...">` display names and
/// `<programme start="..." stop="..." channel="...">` title/desc entries.
/// Timestamps use the XMLTV format `20260910120000 +0000`.
final class XMLTVParser: NSObject, XMLParserDelegate {

    struct Result {
        // channelId -> display name
        var channelNames: [String: String] = [:]
        // channelId -> programmes (sorted by start)
        var programmes: [String: [EPGProgramme]] = [:]
    }

    // MARK: - Parse entry points

    /// Parse raw XMLTV data (already decompressed if needed is handled here:
    /// gzip is detected and inflated automatically).
    static func parse(data: Data) -> Result {
        let xmlData = decompressIfNeeded(data)
        let parser = XMLTVParser()
        return parser.run(on: xmlData)
    }

    /// Fetch and parse from a URL. Supports `.gz` gzip payloads.
    static func parse(url: URL) async throws -> Result {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "XMLTVParser", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode) fetching EPG"])
        }
        return parse(data: data)
    }

    // MARK: - SAX state

    private var result = Result()
    private var elementStack: [String] = []

    // current <channel>
    private var currentChannelId: String?
    private var captureDisplayName = false
    private var displayNameBuffer = ""

    // current <programme>
    private var progChannel: String?
    private var progStart: Date?
    private var progStop: Date?
    private var captureTitle = false
    private var titleBuffer = ""
    private var captureDesc = false
    private var descBuffer = ""

    private func run(on data: Data) -> Result {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        // Sort programmes per channel by start time.
        for key in result.programmes.keys {
            result.programmes[key]?.sort { $0.start < $1.start }
        }
        return result
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        elementStack.append(elementName)

        switch elementName {
        case "channel":
            currentChannelId = attributeDict["id"]
        case "display-name":
            if currentChannelId != nil {
                captureDisplayName = true
                displayNameBuffer = ""
            }
        case "programme":
            progChannel = attributeDict["channel"]
            progStart = XMLTVParser.parseDate(attributeDict["start"])
            progStop = XMLTVParser.parseDate(attributeDict["stop"])
        case "title":
            if progChannel != nil {
                captureTitle = true
                titleBuffer = ""
            }
        case "desc":
            if progChannel != nil {
                captureDesc = true
                descBuffer = ""
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if captureDisplayName {
            displayNameBuffer += string
        } else if captureTitle {
            titleBuffer += string
        } else if captureDesc {
            descBuffer += string
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        switch elementName {
        case "display-name":
            if captureDisplayName, let id = currentChannelId {
                let name = displayNameBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if result.channelNames[id] == nil, !name.isEmpty {
                    result.channelNames[id] = name
                }
            }
            captureDisplayName = false
        case "channel":
            currentChannelId = nil
        case "title":
            captureTitle = false
        case "desc":
            captureDesc = false
        case "programme":
            if let channel = progChannel, let start = progStart, let stop = progStop {
                let programme = EPGProgramme(
                    channelId: channel,
                    title: titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines),
                    desc: descBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : descBuffer.trimmingCharacters(in: .whitespacesAndNewlines),
                    start: start,
                    stop: stop
                )
                result.programmes[channel, default: []].append(programme)
            }
            progChannel = nil
            progStart = nil
            progStop = nil
            titleBuffer = ""
            descBuffer = ""
        default:
            break
        }
        if elementStack.last == elementName {
            elementStack.removeLast()
        }
    }

    // MARK: - Date parsing

    /// Parse XMLTV timestamps like `20260910120000 +0000` or `20260910120000`.
    static func parseDate(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Try with timezone offset first.
        if raw.contains(" ") {
            formatter.dateFormat = "yyyyMMddHHmmss Z"
            if let d = formatter.date(from: raw) { return d }
            // Some feeds use compact offset without space normalization.
            formatter.dateFormat = "yyyyMMddHHmmssZ"
            let compact = raw.replacingOccurrences(of: " ", with: "")
            if let d = formatter.date(from: compact) { return d }
        }
        // No timezone -> assume UTC.
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: raw)
    }

    // MARK: - Decompression

    /// Detect a gzip magic header (0x1f 0x8b) and inflate; otherwise return input.
    static func decompressIfNeeded(_ data: Data) -> Data {
        guard data.count > 2, data[data.startIndex] == 0x1f,
              data[data.startIndex + 1] == 0x8b else {
            return data
        }
        if let inflated = gunzip(data) {
            return inflated
        }
        return data
    }

    /// Inflate gzip data using the Compression framework (zlib raw inflate on the
    /// deflate body, skipping the 10-byte gzip header).
    static func gunzip(_ data: Data) -> Data? {
        #if canImport(Compression)
        // gzip: 10-byte header, optional extra fields, then deflate body,
        // then 8-byte trailer. For the common case (no FEXTRA/FNAME flags) the
        // deflate stream starts at byte 10. Handle common optional fields.
        var index = 10
        let bytes = [UInt8](data)
        guard bytes.count > 18 else { return nil }
        let flags = bytes[3]
        // FEXTRA
        if flags & 0x04 != 0, index + 2 <= bytes.count {
            let xlen = Int(bytes[index]) | (Int(bytes[index + 1]) << 8)
            index += 2 + xlen
        }
        // FNAME
        if flags & 0x08 != 0 {
            while index < bytes.count, bytes[index] != 0 { index += 1 }
            index += 1
        }
        // FCOMMENT
        if flags & 0x10 != 0 {
            while index < bytes.count, bytes[index] != 0 { index += 1 }
            index += 1
        }
        // FHCRC
        if flags & 0x02 != 0 {
            index += 2
        }
        guard index < bytes.count - 8 else { return nil }

        let deflateBody = data.subdata(in: (data.startIndex + index)..<(data.endIndex - 8))
        // Decompressed size (mod 2^32) from gzip trailer.
        let isizeBytes = Array(bytes.suffix(4))
        var isize = Int(isizeBytes[0]) | (Int(isizeBytes[1]) << 8) | (Int(isizeBytes[2]) << 16) | (Int(isizeBytes[3]) << 24)
        if isize <= 0 { isize = max(deflateBody.count * 8, 65_536) }
        let capacity = max(isize, deflateBody.count * 4, 65_536)

        return deflateBody.withUnsafeBytes { (srcRaw: UnsafeRawBufferPointer) -> Data? in
            guard let srcPtr = srcRaw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            let dstPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
            defer { dstPtr.deallocate() }
            let written = compression_decode_buffer(
                dstPtr, capacity,
                srcPtr, deflateBody.count,
                nil,
                COMPRESSION_ZLIB // raw deflate stream
            )
            guard written > 0 else { return nil }
            return Data(bytes: dstPtr, count: written)
        }
        #else
        return nil
        #endif
    }
}
