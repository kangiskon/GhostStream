from pathlib import Path
import plistlib

root = Path('.')
ios_pbx = (root / 'GhostStream.xcodeproj/project.pbxproj').read_text()
tv_pbx = (root / 'GhostStreamTV.xcodeproj/project.pbxproj').read_text()

mobile = root / 'Frameworks/MobileVLCKit.xcframework'
tv = root / 'Frameworks/TVVLCKit.xcframework'

assert mobile.is_dir(), 'MobileVLCKit.xcframework must be bundled in Frameworks/'
assert tv.is_dir(), 'TVVLCKit.xcframework must be bundled in Frameworks/'
assert (mobile / 'Info.plist').is_file(), 'MobileVLCKit Info.plist missing'
assert (tv / 'Info.plist').is_file(), 'TVVLCKit Info.plist missing'

# No network/install phase should be needed in either Xcode target.
assert 'Install MobileVLCKit' not in ios_pbx, 'iOS target still has build-time MobileVLCKit install phase'
assert 'install-mobilevlckit.sh' not in ios_pbx, 'iOS target still references MobileVLCKit downloader'
assert 'Install TVVLCKit' not in tv_pbx, 'tvOS target still has build-time TVVLCKit install phase'
assert 'install-tvvlckit.sh' not in tv_pbx, 'tvOS target still references TVVLCKit downloader'

# Existing embed phases must remain, selecting the correct platform slice and signing device builds.
assert 'Embed MobileVLCKit' in ios_pbx
assert 'embed-mobilevlckit.sh' in ios_pbx
assert 'Embed TVVLCKit' in tv_pbx
assert 'embed-tvvlckit.sh' in tv_pbx

# Download scripts are intentionally removed from the self-contained package.
assert not (root / 'Scripts/install-mobilevlckit.sh').exists()
assert not (root / 'Scripts/install-tvvlckit.sh').exists()

# Verify XCFramework platform slices advertised by the official manifests.
with (mobile / 'Info.plist').open('rb') as f:
    mp = plistlib.load(f)
with (tv / 'Info.plist').open('rb') as f:
    tp = plistlib.load(f)
mlibs = {x['LibraryIdentifier'] for x in mp['AvailableLibraries']}
tlibs = {x['LibraryIdentifier'] for x in tp['AvailableLibraries']}
assert 'ios-arm64_armv7_armv7s' in mlibs
assert 'ios-arm64_i386_x86_64-simulator' in mlibs
assert 'tvos-arm64' in tlibs
assert 'tvos-arm64_x86_64-simulator' in tlibs

print('PASS: VLC frameworks are bundled and no build-time network install phase remains')
