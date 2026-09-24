import Foundation

struct SourceMigrationResult: Equatable {
    let didRun: Bool
    let preservedSourceCount: Int
}

@MainActor
final class SourceMigrationCoordinator {
    static let shared = SourceMigrationCoordinator()

    private let defaults: UserDefaults
    private let store: SourceStore
    private let migrationKey = "ghoststream.v2.migration.completed"

    init(defaults: UserDefaults = .standard, store: SourceStore = .shared) {
        self.defaults = defaults
        self.store = store
    }

    func migrateIfNeeded() -> SourceMigrationResult {
        if defaults.bool(forKey: migrationKey) {
            return SourceMigrationResult(didRun: false, preservedSourceCount: store.sources.count)
        }

        // SourceStore performs the sensitive part of the migration during load:
        // any legacy provider password is moved to Keychain and the persisted
        // source metadata is immediately rewritten without that secret.
        defaults.set(true, forKey: migrationKey)
        return SourceMigrationResult(didRun: true, preservedSourceCount: store.sources.count)
    }

    func cloudProfiles() -> [CloudSourceProfile] {
        store.sources.map(CloudSourceProfile.init(source:))
    }

    func resetMigrationMarkerForTesting() {
        defaults.removeObject(forKey: migrationKey)
    }
}
