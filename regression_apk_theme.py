from pathlib import Path
import json
root=Path(__file__).resolve().parent
swift=(root/'GhostStreamTV'/'TVRootView.swift').read_text()
assert '124/255' in swift and 'accentBright' in swift, 'purple APK palette missing'
assert 'TVPosterFocusModifier' in swift and 'tvPosterFocus' in swift, 'poster-only focus ring missing'
assert 'TVSeasonPickerChip' in swift and 'TVEpisodeCard' in swift, 'series/episode redesign missing'
assert 'selectedSeason' in swift and 'filteredEpisodes' in swift, 'season filtering missing'
assert 'TVMainShell' in swift and 'TVTopNavigation' in swift, 'APK-style top navigation missing'
assert 'TVHeroBanner' in swift and 'Popular Movies' in swift and 'Popular TV Shows' in swift, 'APK-style home hero/rails missing'
assert 'TVLiveListBrowser' in swift and 'TVLiveSidebarChip' in swift, 'APK-style live TV browser missing'
assert (root/'GhostStreamTV'/'Assets.xcassets'/'APKBrandLogo.imageset'/'apk-brand-logo.png').exists(), 'APK brand logo asset missing'
assert (root/'GhostStreamTV'/'Assets.xcassets'/'APKPattern.imageset'/'apk-pattern.png').exists(), 'APK background asset missing'
assert (root/'GhostStreamTV'/'Assets.xcassets'/'App Icon & Top Shelf Image.brandassets'/'Contents.json').exists(), 'tvOS app icon asset missing'
assert (root/'GhostStream'/'Assets.xcassets'/'AppIcon.appiconset'/'Icon-1024.png').exists(), 'iOS app icon missing'
pbx=(root/'GhostStreamTV.xcodeproj'/'project.pbxproj').read_text()
assert 'ASSETCATALOG_COMPILER_APPICON_NAME = "App Icon & Top Shelf Image"' in pbx, 'tvOS app icon build setting missing'
print('apk theme regression: PASS')
