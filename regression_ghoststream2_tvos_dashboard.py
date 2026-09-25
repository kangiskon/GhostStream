from pathlib import Path

root = Path(__file__).parent
paths = [
    root / 'GhostStreamTV/Library/TVLibraryHubView.swift',
    root / 'GhostStreamTV/Devices/TVDevicesView.swift',
    root / 'GhostStreamTV/Intelligence/TVSourceHealthView.swift',
    root / 'GhostStreamTV/Settings/TVSettingsView.swift',
    root / 'GhostStreamTV/TVRootView.swift',
]
for path in paths:
    assert path.exists(), f'missing {path.relative_to(root)}'

text = '\n'.join(path.read_text() for path in paths)
for required in (
    'Home',
    'Library',
    'Devices',
    'Source Health',
    'Settings',
    'Continue Watching',
    'TVLibraryHubView',
    'TVDevicesView',
    'TVSourceHealthView',
    'TVSettingsView',
):
    assert required in text, f'missing TV command center behavior: {required}'

root_text = (root / 'GhostStreamTV/TVRootView.swift').read_text()
assert 'case live = "Live TV"' not in root_text
assert 'case movies = "Movies"' not in root_text
assert 'case series = "Series"' not in root_text
print('ghoststream2 tvOS command-center contract: PASS')
