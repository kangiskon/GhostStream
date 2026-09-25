import CryptoKit
import Foundation
import Security

enum DeviceIdentityError: Error {
    case invalidIdentifier
    case invalidPrivateKey
    case keychain(OSStatus)
}

final class DeviceIdentityService {
    static let shared = DeviceIdentityService()

    private let service = "com.ghoststream.device-identity"
    private let identifierAccount = "device-id"
    private let keyAccount = "curve25519-key-agreement"

    func loadOrCreate() throws -> DeviceIdentity {
        let identifier: UUID
        if let data = read(account: identifierAccount),
           let value = String(data: data, encoding: .utf8),
           let existing = UUID(uuidString: value) {
            identifier = existing
        } else {
            identifier = UUID()
            guard let data = identifier.uuidString.data(using: .utf8) else {
                throw DeviceIdentityError.invalidIdentifier
            }
            try upsert(data, account: identifierAccount)
        }

        let key: Curve25519.KeyAgreement.PrivateKey
        if let data = read(account: keyAccount) {
            do {
                key = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
            } catch {
                throw DeviceIdentityError.invalidPrivateKey
            }
        } else {
            key = Curve25519.KeyAgreement.PrivateKey()
            try upsert(key.rawRepresentation, account: keyAccount)
        }

        return DeviceIdentity(id: identifier, publicKey: key.publicKey.rawRepresentation)
    }

    func loadPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        guard let data = read(account: keyAccount) else {
            _ = try loadOrCreate()
            guard let created = read(account: keyAccount) else {
                throw DeviceIdentityError.invalidPrivateKey
            }
            return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: created)
        }
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
    }

    func clear() {
        delete(account: identifierAccount)
        delete(account: keyAccount)
    }

    private func upsert(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw DeviceIdentityError.keychain(status) }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw DeviceIdentityError.keychain(addStatus) }
    }

    private func read(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
