import Foundation

struct TokenPairDTO: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct AccountDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let email: String
    let emailVerified: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email
        case emailVerified = "email_verified"
        case createdAt = "created_at"
    }
}

struct DeviceDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let platform: String
    let osVersion: String
    let publicKey: String
    let trustState: String
    let lastSeenAt: Date
    let revokedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, platform
        case displayName = "display_name"
        case osVersion = "os_version"
        case publicKey = "public_key"
        case trustState = "trust_state"
        case lastSeenAt = "last_seen_at"
        case revokedAt = "revoked_at"
    }
}

struct SyncEnvelopeDTO: Codable, Equatable {
    let cursor: Int
    let events: [SyncEventDTO]
}

struct SyncEventDTO: Codable, Equatable, Identifiable {
    var id: String { "\(cursor):\(entityType):\(entityKey)" }

    let cursor: Int
    let entityType: String
    let entityKey: String
    let operation: String
    let payload: [String: JSONValue]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case cursor, operation, payload
        case entityType = "entity_type"
        case entityKey = "entity_key"
        case createdAt = "created_at"
    }
}

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct APIErrorEnvelope: Codable, Equatable {
    let code: String
    let message: String?
}

struct APIErrorResponse: Codable, Equatable {
    let detail: APIErrorEnvelope?
}
