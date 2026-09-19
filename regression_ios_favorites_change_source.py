from pathlib import Path
root = Path(__file__).parent
source_store = (root/'GhostStream/Services/SourceStore.swift').read_text()
live = (root/'GhostStream/Views/LiveView.swift').read_text()
movies = (root/'GhostStream/Views/MoviesView.swift').read_text()
series = (root/'GhostStream/Views/SeriesView.swift').read_text()
launcher = (root/'GhostStream/Views/LauncherView.swift').read_text()
settings = (root/'GhostStream/Views/SettingsView.swift').read_text()

checks = {
    'persistent FavoriteStore exists': 'final class FavoriteStore: ObservableObject' in source_store and 'ghoststream.favorites.v1' in source_store,
    'favorites are provider scoped': 'sourceID: UUID' in source_store and 'kind.rawValue' in source_store,
    'live favorite toggle exists': 'FavoriteButton' in live and 'favorites.toggle' in live and 'segment == 1' in live,
    'movies favorite toggle exists': 'FavoriteButton' in movies and 'favorites.toggle' in movies and 'segment == 1' in movies,
    'series favorite toggle exists': 'FavoriteButton' in series and 'favorites.toggle' in series and 'segment == 1' in series,
    'change source has close control': 'CHANGE SOURCE' in launcher and 'closeLauncher' in launcher and 'chevron.left' in launcher,
    'backing out preserves active source': 'title: "Change Source"' in settings and 'private func openSourceSwitcher()' in settings and 'store.disconnect()' not in settings,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('FAIL')
    for name in failed: print('-', name)
    raise SystemExit(1)
print('PASS: iOS favorites + change-source back regression')
