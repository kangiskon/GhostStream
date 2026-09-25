from pathlib import Path

root = Path(__file__).parent
view = root / 'GhostStreamTV/Pairing/TVPairDeviceView.swift'
service = root / 'GhostStreamTV/Pairing/TVPairingService.swift'
project = root / 'GhostStreamTV.xcodeproj/project.pbxproj'
tvroot = root / 'GhostStreamTV/TVRootView.swift'

for path in (view, service):
    assert path.exists(), f'missing {path.relative_to(root)}'

text = view.read_text() + '\n' + service.read_text()
for required in (
    'GHOSTSTREAM',
    'CIQRCodeGenerator',
    'manualCode',
    'expiresAt',
    'Pair this Apple TV',
    'Try Again',
    'Cancel',
    'pairing/sessions',
    '/state?token=',
    '/complete',
    'Curve25519.KeyAgreement.PrivateKey',
    'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly',
):
    assert required in text, f'missing tvOS pairing behavior: {required}'

pbx = project.read_text()
for name in ('TVPairDeviceView.swift', 'TVPairingService.swift'):
    assert name in pbx
    assert f'{name} in Sources' in pbx

assert 'TVPairDeviceView' in tvroot.read_text(), 'TV pairing screen is not reachable from TVRootView'
print('ghoststream2 tvOS pairing contract: PASS')
