from pathlib import Path

root = Path(__file__).parent
swift_files = [
    root / 'GhostStream/Account/APIModels.swift',
    root / 'GhostStream/Account/APIError.swift',
    root / 'GhostStream/Account/GhostStreamAPIClient.swift',
]
for path in swift_files:
    assert path.exists(), f'missing {path.relative_to(root)}'

combined = '\n'.join(path.read_text() for path in swift_files)
for forbidden in ('providerPassword', 'authorizationHeader', 'playlistBody'):
    assert forbidden not in combined, f'forbidden cloud field: {forbidden}'

pbx = (root / 'GhostStream.xcodeproj/project.pbxproj').read_text()
for name in ('APIModels.swift', 'APIError.swift', 'GhostStreamAPIClient.swift'):
    assert name in pbx, f'{name} not added to Xcode project'
    assert f'{name} in Sources' in pbx, f'{name} not in Sources phase'

assert 'protocol GhostStreamAPITransport' in combined
assert 'actor GhostStreamAPIClient' in combined
assert 'accountDeleted' in combined
assert 'https://ghoststreams.ink/api/v1' in combined
print('ghoststream2 api model contract: PASS')
