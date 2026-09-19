from pathlib import Path
src = Path('GhostStreamTV/TVRootView.swift').read_text()
checks = {
    'top nav order includes Home, Live TV, Movies, Series': 'case home = "Home"\n    case live = "Live TV"\n    case movies = "Movies"\n    case series = "Series"' in src,
    'app defaults to Home': '@State private var section: TVMainSection = .home' in src,
    'home dashboard is routed': 'case .home:' in src and 'TVGhostHomeDashboard(section: $section)' in src,
    'live category focus state exists': '@FocusState private var focusedCategoryID: String?' in src,
    'all channels participates in explicit focus': '.focused($focusedCategoryID, equals: "__all__")' in src,
    'provider categories participate in explicit focus': '.focused($focusedCategoryID, equals: category.id)' in src,
    'live browser has explicit focus sections': src.count('.focusSection()') >= 3,
    'settings has explicit focus state': '@FocusState private var sourceFocus: TVSourceFocus?' in src,
    'connect button participates in settings focus': '.focused($sourceFocus, equals: .connect)' in src,
    'transport streams start in compatibility playback': 'private var isTransportStream: Bool' in src and 'if useCompatibilityEngine || isTransportStream' in src,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('FAIL')
    for name in failed: print(' -', name)
    raise SystemExit(1)
print('PASS')
