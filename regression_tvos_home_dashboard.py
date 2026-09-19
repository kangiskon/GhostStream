from pathlib import Path
p = Path('GhostStreamTV/TVRootView.swift')
s = p.read_text()
checks = {
    'home section exists': 'case home = "Home"' in s,
    'home is default': '@State private var section: TVMainSection = .home' in s,
    'home dashboard routed': 'case .home:' in s and 'TVGhostHomeDashboard(' in s,
    'hero asset referenced': 'Image("GhostHomeHero")' in s,
    'hero title': 'ENTERTAINMENT' in s and 'WITHOUT LIMITS' in s,
    'continue watching row': 'Continue Watching' in s,
    'live row': 'title: "Live TV"' in s,
    'movies row': 'title: "Movies"' in s,
    'series row': 'title: "Series"' in s,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('FAIL: ' + ', '.join(failed))
asset = Path('GhostStreamTV/Assets.xcassets/GhostHomeHero.imageset/ghost-home-hero.png')
if not asset.exists():
    raise SystemExit('FAIL: GhostHomeHero asset missing')
print('PASS: tvOS GhostStream home dashboard regression')
