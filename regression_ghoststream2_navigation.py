from pathlib import Path

root = Path(__file__).parent
files = [
    root / 'GhostStream/Shell/GhostStreamNavigation.swift',
    root / 'GhostStream/Shell/GhostStreamShellView.swift',
    root / 'GhostStream/Dashboard/GhostDashboardView.swift',
    root / 'GhostStream/Dashboard/DashboardModels.swift',
    root / 'GhostStream/Library/GhostLibraryHubView.swift',
    root / 'GhostStream/More/GhostMoreView.swift',
]
for path in files:
    assert path.exists(), f'missing {path.relative_to(root)}'

text = '\n'.join(path.read_text() for path in files)
for required in (
    'Home',
    'Library',
    'Devices',
    'Intelligence',
    'More',
    'Continue Watching',
    'Source Health',
    'Paired Devices',
    'Recent Activity',
):
    assert required in text, f'missing navigation/dashboard element: {required}'

assert 'case home, library, devices, intelligence, more' in text
assert 'Label("Live"' not in text
assert 'Label("Movies"' not in text
assert 'Label("Series"' not in text
print('ghoststream2 navigation contract: PASS')
