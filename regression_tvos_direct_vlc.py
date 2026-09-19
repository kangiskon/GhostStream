from pathlib import Path
root = Path(__file__).resolve().parent
p = (root / 'GhostStreamTV.xcodeproj/project.pbxproj').read_text()
s = (root / 'GhostStreamTV/TVRootView.swift').read_text()
xc = root / 'Frameworks/TVVLCKit.xcframework'
assert 'XCRemoteSwiftPackageReference "vlckit-spm"' not in p, 'broken SPM dependency still present'
assert 'VLCKitSPM in Frameworks' not in p, 'broken SPM product still linked'
assert 'VLCKitSPM' not in s, 'VLCKitSPM import/condition still present'
assert 'import TVVLCKit' in s, 'TVVLCKit import missing'
assert 'Install TVVLCKit' not in p and 'install-tvvlckit.sh' not in p, 'network installer phase must be removed'
assert xc.is_dir(), 'bundled TVVLCKit.xcframework missing'
assert 'TVVLCKit.xcframework/tvos-arm64_x86_64-simulator' in p, 'simulator framework path missing'
assert 'TVVLCKit.xcframework/tvos-arm64' in p, 'device framework path missing'
assert 'Embed TVVLCKit' in p and 'embed-tvvlckit.sh' in p, 'embed/sign build phase missing'
print('PASS: self-contained direct TVVLCKit integration configured')
