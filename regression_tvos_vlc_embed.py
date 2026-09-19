from pathlib import Path

root = Path(__file__).resolve().parent
pbx = (root / 'GhostStreamTV.xcodeproj' / 'project.pbxproj').read_text()
embed_script = root / 'Scripts' / 'embed-tvvlckit.sh'

assert 'Embed TVVLCKit' in pbx, 'tvOS target must contain an Embed TVVLCKit build phase'
assert '@executable_path/Frameworks' in pbx, 'tvOS target must search embedded frameworks at runtime'
assert embed_script.exists(), 'embed-tvvlckit.sh must exist'
script = embed_script.read_text()
assert 'FRAMEWORKS_FOLDER_PATH' in script, 'embed script must copy into the app Frameworks folder'
assert 'TVVLCKit.framework' in script, 'embed script must embed TVVLCKit.framework'
assert 'codesign' in script, 'embedded dynamic framework must be signed for device builds'
print('tvOS TVVLCKit embed regression: PASS')
