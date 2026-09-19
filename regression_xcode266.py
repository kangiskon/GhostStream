from pathlib import Path
root = Path(__file__).resolve().parent
ios = (root / 'GhostStream.xcodeproj/project.pbxproj').read_text()
tvos = (root / 'GhostStreamTV.xcodeproj/project.pbxproj').read_text()
for name, pbx in [('iOS', ios), ('tvOS', tvos)]:
    assert 'LastUpgradeCheck = 2660;' in pbx, f'{name}: Xcode 26.6 upgrade marker missing'
    assert 'LastSwiftUpdateCheck = 2660;' in pbx, f'{name}: Swift update marker missing'
    assert 'CreatedOnToolsVersion = 26.6;' in pbx, f'{name}: Xcode 26.6 tools marker missing'
    assert 'SWIFT_VERSION = 5.0;' in pbx
    assert 'SWIFT_STRICT_CONCURRENCY = minimal;' in pbx
    assert 'ENABLE_USER_SCRIPT_SANDBOXING = NO;' in pbx
assert 'TARGETED_DEVICE_FAMILY = "1,2";' in ios
assert 'PRODUCT_BUNDLE_IDENTIFIER = com.ghoststream.tv;' in tvos
assert (root / 'Frameworks/MobileVLCKit.xcframework').is_dir()
assert (root / 'Frameworks/TVVLCKit.xcframework').is_dir()
print('PASS Xcode 26.6 project compatibility')
