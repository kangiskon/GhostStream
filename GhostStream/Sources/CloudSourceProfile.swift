import CryptoKit
import Foundation

struct CloudSourceProfile: Codable, Equatable, Identifiable {
    let sourceID: UUID
    let displayName: String
    let kind: String
    let fingerprint: String
    let capabilities: [String: Bool]
    let updatedAt: Date

    var id: UUID { sourceID }

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case displayName = "display_name"
        case kind
        case fingerprint
        case capabilities
        case updatedAt = "updated_at"
    }

    init(source: Source, updatedAt: Date = Date()) {
        sourceID = source.id
        displayName = source.name
        switch source.kind {
        case .m3uURL:
            kind = "m3u_url"
            capabilities = ["live": true, "movies": false, "series": false]
        case .m3uText:
            kind = "m3u_text"
            capabilities = ["live": true, "movies": false, "series": false]
        case .xtream:
            kind = "provider"
            capabilities = ["live": true, "movies": true, "series": true]
        }
        let digest = SHA256.hash(data: Data(source.id.uuidString.utf8))
        fingerprint = digest.map { String(format: "%02x", $0) }.joined()
        self.updatedAt = updatedAt
    }
}
