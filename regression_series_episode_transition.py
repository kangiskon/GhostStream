from pathlib import Path

root = Path(__file__).resolve().parent
ios = (root / 'GhostStream/Views/PlayerView.swift').read_text()
tv = (root / 'GhostStreamTV/TVRootView.swift').read_text()

# Episode changes must be two-phase: remove the current playback surface first,
# then install the next episode after teardown has had a run-loop turn.
assert '@State private var episodeSwitchInProgress = false' in ios
assert 'if episodeSwitchInProgress {' in ios
assert 'DispatchQueue.main.asyncAfter' in ios
assert 'episodeSwitchInProgress = true' in ios

assert '@State private var episodeSwitchInProgress = false' in tv
assert 'if episodeSwitchInProgress {' in tv
assert 'episodeSwitchInProgress = true' in tv

# A coordinator that is being dismantled must ignore any late VLC callbacks.
assert 'private var isStopped = false' in ios
assert 'guard !isStopped else { return }' in ios
assert 'isStopped = true' in ios

assert 'private var isStopped = false' in tv
assert 'guard !isStopped else { return }' in tv
assert 'isStopped = true' in tv

# Never retarget an existing VLCMediaPlayer to a different episode URL.
assert 'guard currentURL == url else { return }' in ios
assert 'guard currentURL == url else { return }' in tv

print('series episode transition regression checks passed')
