from pathlib import Path

root = Path(__file__).resolve().parent
ios_root = (root / 'GhostStream/Views/RootTabView.swift').read_text()
launcher = (root / 'GhostStream/Views/LauncherView.swift').read_text()
movies = (root / 'GhostStream/Views/MoviesView.swift').read_text()
series = (root / 'GhostStream/Views/SeriesView.swift').read_text()
tv = (root / 'GhostStreamTV/TVRootView.swift').read_text()

# Invalid SF Symbol must not remain.
assert 'icon: "clapperboard"' not in ios_root
assert 'icon: "movieclapper"' in ios_root

# Widths used directly by .frame(width:) must be clamped during size transitions.
for text in (ios_root, launcher, movies, series):
    assert 'let contentWidth = max(' in text

# AVKit controls must not be activated while the representable has zero width.
assert 'controller.showsPlaybackControls = false' in tv
assert 'schedulePlaybackControls' in tv
assert 'controller.view.bounds.width >= 200' in tv

# Episode URL changes must force a fresh playback surface/coordinator.
assert '.id("native-\\(candidate.absoluteString)")' in tv
assert '.id("compatibility-\\(effectiveURLString)")' in tv
assert 'tvAudioTracks = []' in tv and 'tvSubtitleTracks = []' in tv

# A source successfully loaded from the modal must close that modal.
assert 'onConnected: (() -> Void)?' in tv
assert 'onClose: (() -> Void)?' in tv
assert 'onConnected?()' in tv
assert 'TVSourceSetupView(' in tv and 'onConnected: { showSources = false }' in tv

# iOS series episode changes must also rebuild playback surfaces and use episode resume IDs.
ios_player = (root / 'GhostStream/Views/PlayerView.swift').read_text()
assert '.id("compatibility-\\(url.absoluteString)")' in ios_player
assert '.id("native-\\(url.absoluteString)-\\(tryOriginalNativeURL)")' in ios_player
assert 'private var resumeID: String { currentSeriesEpisode?.id ?? contentID ?? effectiveURLString }' in ios_player
assert 'mediaPlayer.delegate = nil' in ios_player

print('tvOS player/source stability regression checks passed')
