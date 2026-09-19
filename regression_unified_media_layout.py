from pathlib import Path
root = Path(__file__).parent
movies = (root / 'GhostStream/Views/MoviesView.swift').read_text()
series = (root / 'GhostStream/Views/SeriesView.swift').read_text()
root_view = (root / 'GhostStream/Views/RootTabView.swift').read_text()
assert 'phoneColumnCount' in movies
assert 'availableWidth >= 390 ? 3 : 2' in movies
assert 'padColumnCount' in movies and 'min(6' in movies
assert 'phoneColumnCount' in series
assert 'availableWidth >= 390 ? 3 : 2' in series
assert 'SEASON' in series and 'SeriesPlaybackContext' in series
assert 'Theme.accentBright' in root_view
print('PASS unified media layout')
