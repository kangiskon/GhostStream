from pathlib import Path

root = Path(__file__).parent
progress = root / 'GhostStreamTV/Shared/TVPlaybackProgressStore.swift'
sync = root / 'GhostStreamTV/Shared/TVSyncService.swift'
tvroot = root / 'GhostStreamTV/TVRootView.swift'

for path in (progress, sync, tvroot):
    assert path.exists(), f'missing {path.relative_to(root)}'

text = progress.read_text() + '\n' + sync.read_text() + '\n' + tvroot.read_text()

for required in (
    'TVPlaybackProgressStore.shared',
    'TVSyncService.shared',
    'positionSeconds',
    'durationSeconds',
    'seriesID',
    'Continue Watching',
    'TVResumeContentDestination',
    'publishProgress',
    'completionRatio >= 0.95',
    'devices/me/transfers',
):
    assert required in text, f'missing tvOS continuity behavior: {required}'

assert 'continueMovies' not in tvroot.read_text(), 'TV home still uses fake movie Continue Watching shelf'
assert 'continueSeries' not in tvroot.read_text(), 'TV home still uses fake series Continue Watching shelf'
print('ghoststream2 tvOS continuity contract: PASS')
