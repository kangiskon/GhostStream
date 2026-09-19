from pathlib import Path
root = Path(__file__).parent
app = (root / 'GhostStream/GhostStreamApp.swift').read_text()
asset = root / 'GhostStream/Assets.xcassets/GhostHomeHero.imageset/Contents.json'
root_view = (root / 'GhostStream/Views/RootTabView.swift').read_text()
assert '124/255' in app and '92/255' in app, 'iOS accent must match tvOS purple'
assert 'static let accentBright' in app
assert 'static let heroGlow' in app
assert asset.exists(), 'GhostHomeHero must be present in the iOS asset catalog'
assert 'case home, live, movies, series, sources' in root_view
assert 'Label("Sources", systemImage:' in root_view
assert 'UIDevice.current.userInterfaceIdiom == .pad' in root_view
assert 'GhostTopNavigation' in root_view
assert 'TabView(selection:' in root_view
assert 'SettingsView()' in root_view
assert 'Image("GhostHomeHero")' in root_view
tv = (root / 'GhostStreamTV/TVRootView.swift').read_text()
for token in ['TVGhostHomeHero','TVLivePreviewPanel','previewWorkItem?.cancel()','episodeSwitchInProgress','GhostHomeHero']:
    assert token in tv, f'tvOS reference behavior missing: {token}'
print('PASS unified theme/home')
