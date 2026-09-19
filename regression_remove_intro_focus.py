from pathlib import Path

root = Path(__file__).parent

ios_app = (root / 'GhostStream' / 'GhostStreamApp.swift').read_text()
tv_app = (root / 'GhostStreamTV' / 'GhostStreamTVApp.swift').read_text()
tv_root = (root / 'GhostStreamTV' / 'TVRootView.swift').read_text()
ios_pbx = (root / 'GhostStream.xcodeproj' / 'project.pbxproj').read_text()
tv_pbx = (root / 'GhostStreamTV.xcodeproj' / 'project.pbxproj').read_text()

# Loading video must be removed from both apps and both project resource phases.
assert 'showingIntro' not in ios_app, 'iOS still gates the app behind the intro screen'
assert 'GhostIntroView' not in ios_app, 'iOS intro view still exists'
assert 'GhostStreamIntro.mp4' not in ios_pbx, 'iOS project still bundles the intro MP4'
assert not (root / 'GhostStream' / 'GhostStreamIntro.mp4').exists(), 'iOS intro MP4 still exists'

assert 'showingIntro' not in tv_app, 'tvOS still gates the app behind the intro screen'
assert 'TVGhostIntroView' not in tv_app, 'tvOS intro view still exists'
assert 'GhostStreamIntro.mp4' not in tv_pbx, 'tvOS project still bundles the intro MP4'
assert not (root / 'GhostStreamTV' / 'GhostStreamIntro.mp4').exists(), 'tvOS intro MP4 still exists'

# tvOS media navigation must use the same focus-preserving custom button style
# as the working home shelves instead of PlainButtonStyle.
plain_count = tv_root.count('.buttonStyle(.plain)')
assert plain_count == 0, f'tvOS still has {plain_count} plain NavigationLink styles that suppress the custom remote focus treatment'

# Sanity: the custom focus-preserving style must remain available and used.
assert 'private struct TVGhostFocusStyle: ButtonStyle' in tv_root
assert tv_root.count('.buttonStyle(TVGhostFocusStyle())') >= 10, 'Expected media navigation links to use TVGhostFocusStyle'

print('PASS: intro removed and tvOS media links use focus-preserving button style')
