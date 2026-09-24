import Foundation

enum GlobalWipeReason {
    case accountDeleted
    case userRequestedDeletion
}

@MainActor
final class GlobalDeletionCoordinator {
    static let shared = GlobalDeletionCoordinator()

    private weak var accountStore: AccountStore?
    private weak var library: LibraryViewModel?
    private weak var epg: EPGService?

    func configure(
        accountStore: AccountStore,
        library: LibraryViewModel,
        epg: EPGService
    ) {
        self.accountStore = accountStore
        self.library = library
        self.epg = epg
    }

    func wipeAndSignOut(reason: GlobalWipeReason) async {
        SourceStore.shared.wipeAllLocalData()
        FavoriteStore.shared.clearAll()
        PlaybackProgressStore.shared.clearAll()
        ActivityStore.shared.clearAll()
        SyncEngine.shared.clearLocalState()
        SourceMigrationCoordinator.shared.clearMigrationMarker()
        SessionVault.clear()
        DeviceIdentityService.shared.clear()
        URLCache.shared.removeAllCachedResponses()

        library?.reset()
        epg?.clear()

        if let accountStore {
            await accountStore.signOut()
        }
    }
}
