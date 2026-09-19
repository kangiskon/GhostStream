from pathlib import Path
root = Path(__file__).parent
launcher = (root / 'GhostStream/Views/LauncherView.swift').read_text()
settings = (root / 'GhostStream/Views/SettingsView.swift').read_text()
assert 'Image("GhostHomeHero")' in launcher
assert 'Theme.accentBright' in launcher
assert 'CONTENT & RIGHTS' in settings
assert 'GhostStream uses the black and purple' in settings
player = (root / 'GhostStream/Views/PlayerView.swift').read_text()
assert 'scheduleControlsHide()' in player
assert 'controlsHideWorkItem?.cancel()' in player
assert 'episodeSwitchInProgress' in player
assert 'DispatchQueue.main.asyncAfter(deadline: .now() + 0.20)' in player
live_start = player.index('private var liveMockupOverlay')
live_end = player.index('private var vodControlsOverlay')
assert 'Text(title)' not in player[live_start:live_end]
assert 'loadMediaSelectionGroup(for:' in player
print('PASS unified sources/player')
