import plistlib
from pathlib import Path
p=Path('/mnt/data/tv_playback_debug/GhostStreamTV/Info.plist')
with p.open('rb') as f:
    d=plistlib.load(f)
assert d.get('CFBundleExecutable') == '$(EXECUTABLE_NAME)', d.get('CFBundleExecutable')
assert d.get('CFBundlePackageType') == 'APPL', d.get('CFBundlePackageType')
print('tvOS bundle plist regression check passed')
