from pathlib import Path

root = Path(__file__).parent
paths = [
    root / 'GhostStream/Sync/SyncEngine.swift',
    root / 'GhostStream/Activity/PlaybackProgressStore.swift',
    root / 'GhostStream/Activity/ActivityStore.swift',
    root / 'GhostStream/Account/GlobalDeletionCoordinator.swift',
]
for path in paths:
    assert path.exists(), f'missing {path.relative_to(root)}'

text = '\n'.join(path.read_text() for path in paths)
for required in (
    'wipeAllLocalData',
    'FavoriteStore.shared.clearAll',
    'PlaybackProgressStore.shared.clearAll',
    'ActivityStore.shared.clearAll',
    'SessionVault.clear',
    'DeviceIdentityService.shared.clear',
    'library?.reset',
    'epg?.clear',
    'accountDeleted',
    'syncCursor',
):
    assert required in text, f'missing deletion/sync behavior: {required}'

print('ghoststream2 sync/deletion contract: PASS')
