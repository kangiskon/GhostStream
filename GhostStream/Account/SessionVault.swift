import Foundation
import Security

enum SessionVaultError: Error {
    case encodingFailed
    case keychain(OSStatus)
}

enum SessionVault {
    private static let service = "com.ghoststream.account.session"
    private static let refreshTokenAccount = "refresh-token"
    private static let accountIDAccount = "account-id"

    static func saveRefreshToken(_ refreshToken: String, accountID: UUID) throws {
        guard let tokenData = refreshToken.data(using: .utf8),
              let accountData = accountID.uuidString.data(using: .utf8) else {
            throw SessionVaultError.encodingFailed
        }
        try upsert(tokenData, account: refreshTokenAccount)
        try upsert(accountData, account: accountIDAccount)
    }

    static func readRefreshToken() -> String? {
        guard let data = read(account: refreshTokenAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func readAccountID() -> UUID? {
        guard let data = read(account: accountIDAccount),
              let value = String(data: data, encoding: .utf8) else { return nil }
        return UUID(uuidString: value)
    }

    static func clear() {
        delete(account: refreshTokenAccount)
        delete(account: accountIDAccount)
    }

    private static func upsert(_ data: Data, account: String) throws {
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
        if status == errSecItemSuccess { return }
        guard status == errSecItemNotFound else { throw SessionVaultError.keychain(status) }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw SessionVaultError.keychain(addStatus) }
    }

    private static func read(account: String) -> Data? {
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

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
