import CryptoKit
import Foundation
import Security
import UIKit

struct TVPairingSessionDTO: Codable, Equatable, Identifiable {
    var id: UUID { pairingID }

    let pairingID: UUID
    let manualCode: String
    let qrToken: String
    let qrPayload: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case pairingID = "pairing_id"
        case manualCode = "manual_code"
        case qrToken = "qr_token"
        case qrPayload = "qr_payload"
        case expiresAt = "expires_at"
    }
}

struct TVPairingStateDTO: Codable, Equatable {
    let pairingID: UUID
    let state: String
    let expiresAt: Date
    let deviceID: UUID
    let accountID: UUID?

    enum CodingKeys: String, CodingKey {
        case state
        case pairingID = "pairing_id"
        case expiresAt = "expires_at"
        case deviceID = "device_id"
        case accountID = "account_id"
    }
}

struct TVTokenPairDTO: Codable, Equatable {
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

struct TVDeviceIdentity {
    let id: UUID
    let publicKey: Data

    var publicKeyBase64: String { publicKey.base64EncodedString() }
}

enum TVPairingError: LocalizedError {
    case invalidResponse
    case server(Int, String?)
    case noRefreshToken
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GhostStream received an invalid pairing response."
        case .server(let status, let code):
            if status == 410 || code == "pairing_expired" {
                return "This pairing code expired. Try again to generate a new code."
            }
            return code.map { "Pairing failed: \($0)." } ?? "Pairing failed with server status \(status)."
        case .noRefreshToken:
            return "This Apple TV is not paired with a GhostStream account."
        case .keychain(let status):
            return "Secure storage failed with status \(status)."
        }
    }
}

final class TVDeviceIdentityStore {
    static let shared = TVDeviceIdentityStore()

    private let service = "com.ghoststream.tv.device-identity"
    private let idAccount = "device-id"
    private let keyAccount = "curve25519-key-agreement"

    func loadOrCreate() throws -> TVDeviceIdentity {
        let id: UUID
        if let data = read(account: idAccount),
           let string = String(data: data, encoding: .utf8),
           let existing = UUID(uuidString: string) {
            id = existing
        } else {
            id = UUID()
            try write(Data(id.uuidString.utf8), account: idAccount)
        }

        let key: Curve25519.KeyAgreement.PrivateKey
        if let data = read(account: keyAccount) {
            key = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
        } else {
            key = Curve25519.KeyAgreement.PrivateKey()
            try write(key.rawRepresentation, account: keyAccount)
        }

        return TVDeviceIdentity(id: id, publicKey: key.publicKey.rawRepresentation)
    }

    func loadPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        guard let data = read(account: keyAccount) else {
            _ = try loadOrCreate()
            guard let created = read(account: keyAccount) else {
                throw TVPairingError.invalidResponse
            }
            return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: created)
        }
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    func clear() {
        delete(account: idAccount)
        delete(account: keyAccount)
    }

    private func read(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private func write(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let update = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw TVPairingError.keychain(update) }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let add = SecItemAdd(item as CFDictionary, nil)
        guard add == errSecSuccess else { throw TVPairingError.keychain(add) }
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum TVSessionVault {
    private static let service = "com.ghoststream.tv.account-session"
    private static let refreshAccount = "refresh-token"

    static func saveRefreshToken(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: refreshAccount,
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let update = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw TVPairingError.keychain(update) }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let add = SecItemAdd(item as CFDictionary, nil)
        guard add == errSecSuccess else { throw TVPairingError.keychain(add) }
    }

    static func readRefreshToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: refreshAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: refreshAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

actor TVPairingService {
    static let shared = TVPairingService()
    static let productionBaseURL = URL(string: "https://ghoststreams.ink/api/v1")!

    private let baseURL: URL
    private var accessToken: String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL = TVPairingService.productionBaseURL) {
        self.baseURL = baseURL

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func createSession() async throws -> TVPairingSessionDTO {
        let identity = try TVDeviceIdentityStore.shared.loadOrCreate()
        let body = TVPairingCreateBody(
            deviceID: identity.id,
            displayName: UIDevice.current.name,
            platform: "tvos",
            osVersion: UIDevice.current.systemVersion,
            publicKey: identity.publicKeyBase64
        )
        return try await send(path: "pairing/sessions", method: "POST", body: body)
    }

    func state(for session: TVPairingSessionDTO) async throws -> TVPairingStateDTO {
        let token = session.qrToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? session.qrToken
        return try await send(
            path: "pairing/\(session.pairingID.uuidString)/state?token=\(token)",
            method: "GET",
            body: Optional<String>.none
        )
    }

    func complete(_ session: TVPairingSessionDTO) async throws -> TVTokenPairDTO {
        let pair: TVTokenPairDTO = try await send(
            path: "pairing/\(session.pairingID.uuidString)/complete",
            method: "POST",
            body: TVPairingCompleteBody(qrToken: session.qrToken)
        )
        try TVSessionVault.saveRefreshToken(pair.refreshToken)
        accessToken = pair.accessToken
        return pair
    }

    func validAccessToken() async throws -> String {
        if let accessToken { return accessToken }
        guard let refresh = TVSessionVault.readRefreshToken() else {
            throw TVPairingError.noRefreshToken
        }
        let pair: TVTokenPairDTO = try await send(
            path: "auth/refresh",
            method: "POST",
            body: TVRefreshBody(refreshToken: refresh)
        )
        try TVSessionVault.saveRefreshToken(pair.refreshToken)
        accessToken = pair.accessToken
        return pair.accessToken
    }

    func clearSession() {
        accessToken = nil
        TVSessionVault.clear()
    }

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let parts = cleanPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var url = baseURL
        for segment in parts[0].split(separator: "/", omittingEmptySubsequences: true) {
            url.appendPathComponent(String(segment))
        }
        if parts.count == 2 {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.percentEncodedQuery = String(parts[1])
            guard let queryURL = components?.url else { throw TVPairingError.invalidResponse }
            url = queryURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TVPairingError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let error = try? decoder.decode(TVAPIErrorResponse.self, from: data)
            throw TVPairingError.server(http.statusCode, error?.detail?.code)
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw TVPairingError.invalidResponse
        }
    }
}

private struct TVPairingCreateBody: Codable {
    let deviceID: UUID
    let displayName: String
    let platform: String
    let osVersion: String
    let publicKey: String

    enum CodingKeys: String, CodingKey {
        case platform
        case deviceID = "device_id"
        case displayName = "display_name"
        case osVersion = "os_version"
        case publicKey = "public_key"
    }
}

private struct TVPairingCompleteBody: Codable {
    let qrToken: String
    enum CodingKeys: String, CodingKey { case qrToken = "qr_token" }
}

private struct TVRefreshBody: Codable {
    let refreshToken: String
    enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
}

private struct TVAPIErrorResponse: Codable {
    let detail: TVAPIErrorDetail?
}

private struct TVAPIErrorDetail: Codable {
    let code: String?
}
