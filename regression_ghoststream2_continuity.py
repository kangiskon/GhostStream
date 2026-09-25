from pathlib import Path

root = Path(__file__).parent
player = (root / 'GhostStream/Views/PlayerView.swift').read_text()
progress = (root / 'GhostStream/Activity/PlaybackProgressStore.swift').read_text()
continue_view = root / 'GhostStream/Activity/ContinueWatchingView.swift'
dashboard = (root / 'GhostStream/Dashboard/GhostDashboardView.swift').read_text()
sync = (root / 'GhostStream/Sync/SyncEngine.swift').read_text()

assert continue_view.exists(), 'ContinueWatchingView.swift is missing'
cw = continue_view.read_text()

for required in (
    'PlaybackProgressStore.shared',
    'SyncEngine.shared.enqueueProgress',
    'ActivityStore.shared.record',
    'publishProgress',
    'completed: completionRatio >= 0.95',
):
    assert required in player, f'missing player continuity behavior: {required}'

for required in (
    'Continue Watching',
    'ResumeEpisodeDestination',
    'positionSeconds',
    'durationSeconds',
):
    assert required in cw, f'missing Continue Watching behavior: {required}'

assert 'ContinueWatchingView' in dashboard
assert 'seriesID' in progress
assert 'title' in progress
assert 'series_id' in sync
print('ghoststream2 continuity contract: PASS')
