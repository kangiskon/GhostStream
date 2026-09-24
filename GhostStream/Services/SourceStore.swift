import Foundation
import Combine
import Security

/// Persists user-provided sources locally using UserDefaults (JSON encoded).
/// No content is ever bundled; this store starts empty on first run.
final class SourceStore: ObservableObject {

    static let shared = SourceStore()

    @Published private(set) var sources: [Source] = []
    @Published var activeSourceID: UUID?

    private let sourcesKey = "ghoststream.sources.v1"
    private let activeKey = "ghoststream.activeSource.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// The source currently connected for playback. A nil ID means the user
    /// deliberately logged out; saved sources remain available for one-tap switching.
    var activeSource: Source? {
        guard let id = activeSourceID else { return nil }
        return sources.first { $0.id == id }
    }

    // MARK: - Mutations

    func add(_ source: Source) {
        sources.append(source)
        if activeSourceID == nil {
            activeSourceID = source.id
        }
        persist()
    }

    func update(_ source: Source) {
        guard let idx = sources.firstIndex(where: { $0.id == source.id }) else { return }
        sources[idx] = source
        invalidateLibraryCache(for: source.id)
        persist()
    }

    func remove(_ source: Source) {
        sources.removeAll { $0.id == source.id }
        if activeSourceID == source.id {
            activeSourceID = nil
        }
        PasswordVault.delete(for: source.id)
        invalidateLibraryCache(for: source.id)
        persist()
    }

    func setActive(_ source: Source) {
        activeSourceID = source.id
        persist()
    }

    /// Disconnect from the current service without forgetting any saved source.
    func disconnect() {
        activeSourceID = nil
        persist()
    }

    /// Removes every locally saved source and its Keychain credential.
    /// Used only by explicit global account deletion / wipe flows.
    func wipeAllLocalData() {
        let existingIDs = sources.map(\.id)
        for id in existingIDs {
            PasswordVault.delete(for: id)
        }

        sources = []
        activeSourceID = nil
        defaults.removeObject(forKey: sourcesKey)
        defaults.removeObject(forKey: activeKey)

        if let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let libraryRoot = base.appendingPathComponent("GhostStreamLibrary", isDirectory: true)
            try? FileManager.default.removeItem(at: libraryRoot)
        }
    }

    /// Purge source-specific cached library metadata when a source is changed or deleted.
    /// This avoids showing an old account's titles after its credentials are edited.
    private func invalidateLibraryCache(for id: UUID) {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let url = base.appendingPathComponent("GhostStreamLibrary", isDirectory: true)
            .appendingPathComponent(id.uuidString + ".json")
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Persistence

    private func load() {
        if let data = defaults.data(forKey: sourcesKey),
           var decoded = try? JSONDecoder().decode([Source].self, from: data) {
            // Migrate older builds that stored provider passwords in UserDefaults,
            // then restore passwords from the iOS Keychain for runtime use.
            for index in decoded.indices {
                if let legacyPassword = decoded[index].password, !legacyPassword.isEmpty {
                    PasswordVault.save(legacyPassword, for: decoded[index].id)
                }
                if decoded[index].kind == .xtream {
                    decoded[index].password = PasswordVault.read(for: decoded[index].id)
                }
            }
            sources = decoded
        }
        if let idString = defaults.string(forKey: activeKey),
           let id = UUID(uuidString: idString),
           sources.contains(where: { $0.id == id }) {
            activeSourceID = id
        } else {
            activeSourceID = nil
        }
        // Rewrite once so any legacy plaintext password is removed from preferences.
        persist()
    }

    private func persist() {
        // Store provider passwords in Keychain and persist only redacted source metadata.
        var redacted = sources
        for index in redacted.indices {
            if redacted[index].kind == .xtream {
                if let password = redacted[index].password, !password.isEmpty {
                    PasswordVault.save(password, for: redacted[index].id)
                }
                redacted[index].password = nil
            }
        }
        if let data = try? JSONEncoder().encode(redacted) {
            defaults.set(data, forKey: sourcesKey)
        }
        if let id = activeSourceID {
            defaults.set(id.uuidString, forKey: activeKey)
        } else {
            defaults.removeObject(forKey: activeKey)
        }
    }
}

/// Tiny Keychain wrapper used only for user-supplied provider passwords.
/// Passwords never need to leave the device for GhostStream's own storage.
private enum PasswordVault {
    private static let service = "com.ghoststream.saved-provider"

    static func save(_ password: String, for id: UUID) {
        guard let data = password.data(using: .utf8) else { return }
        let account = id.uuidString
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var item = base
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    static func read(for id: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(for id: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}


// MARK: - Favorites

enum FavoriteKind: String {
    case live
    case vod
    case series
}

/// Persists favorites locally and scopes every favorite to the source that
/// supplied it, so two providers can safely reuse the same stream/series IDs.
final class FavoriteStore: ObservableObject {
    static let shared = FavoriteStore()

    @Published private(set) var keys: Set<String> = []

    private let defaults: UserDefaults
    private let favoritesKey = "ghoststream.favorites.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.stringArray(forKey: favoritesKey) {
            keys = Set(saved)
        }
    }

    func contains(sourceID: UUID, kind: FavoriteKind, id: String) -> Bool {
        keys.contains(makeKey(sourceID: sourceID, kind: kind, id: id))
    }

    func toggle(sourceID: UUID, kind: FavoriteKind, id: String) {
        let key = makeKey(sourceID: sourceID, kind: kind, id: id)
        if keys.contains(key) { keys.remove(key) }
        else { keys.insert(key) }
        defaults.set(Array(keys).sorted(), forKey: favoritesKey)
    }

    private func makeKey(sourceID: UUID, kind: FavoriteKind, id: String) -> String {
        "\(sourceID.uuidString)|\(kind.rawValue)|\(id)"
    }
}
