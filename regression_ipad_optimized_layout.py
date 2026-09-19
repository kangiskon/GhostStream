from pathlib import Path

root = Path(__file__).parent
root_tab = (root/'GhostStream/Views/RootTabView.swift').read_text()
live = (root/'GhostStream/Views/LiveView.swift').read_text()
movies = (root/'GhostStream/Views/MoviesView.swift').read_text()
series = (root/'GhostStream/Views/SeriesView.swift').read_text()
project = (root/'GhostStream.xcodeproj/project.pbxproj').read_text()

checks = {
    'universal target keeps iPhone + iPad': 'TARGETED_DEVICE_FAMILY = "1,2";' in project or 'TARGETED_DEVICE_FAMILY = 1,2;' in project,
    'iPad branch exists': 'userInterfaceIdiom == .pad' in root_tab,
    'iPad uses full-screen destinations': 'iPadFullScreenDestination' in root_tab and 'GhostPadSidebar' not in root_tab,
    'iPhone TabView retained': 'TabView(selection: $selectedTab)' in root_tab,
    'iPad has Back-to-Home control': 'Label("Back", systemImage: "chevron.left")' in root_tab and 'selectedTab = 0' in root_tab,
    'iPad home uses four columns': 'Array(repeating: GridItem(.flexible()' in root_tab and 'count: isPadLike ? 4 : 2' in root_tab,
    'iPad live layout detects pad width': 'isPadLike' in live and 'categoryGrid' in live,
    'movies still optimize wide grids': 'availableWidth >= 1000 ? 6 : 5' in movies,
    'series still optimize wide grids': 'availableWidth >= 1000 ? 6 : 5' in series,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if failed:
    raise SystemExit('Missing iPad layout requirements: ' + ', '.join(failed))
