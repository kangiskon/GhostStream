# Historical filename retained so older local test commands keep working.
# The project itself has been upgraded to Xcode 26.6.
from pathlib import Path
root = Path(__file__).resolve().parent
ios = (root / 'GhostStream.xcodeproj/project.pbxproj').read_text()
tvos = (root / 'GhostStreamTV.xcodeproj/project.pbxproj').read_text()
for name, pbx in [('iOS', ios), ('tvOS', tvos)]:
    assert 'LastUpgradeCheck = 2660;' in pbx, f'{name}: Xcode 26.6 upgrade marker missing'
    assert 'LastSwiftUpdateCheck = 2660;' in pbx, f'{name}: Xcode 26.6 Swift marker missing'
    assert 'CreatedOnToolsVersion = 26.6;' in pbx, f'{name}: Xcode 26.6 tools marker missing'
    assert 'SWIFT_VERSION = 5.0;' in pbx
    assert 'SWIFT_STRICT_CONCURRENCY = minimal;' in pbx
    assert 'ENABLE_USER_SCRIPT_SANDBOXING = NO;' in pbx
assert (root / 'Frameworks/MobileVLCKit.xcframework').is_dir()
assert (root / 'Frameworks/TVVLCKit.xcframework').is_dir()
print('PASS: historical Xcode regression now validates Xcode 26.6 project markers')
