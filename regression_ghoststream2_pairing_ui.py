from pathlib import Path

root = Path(__file__).parent
paths = [
    root / 'GhostStream/Devices/PairDeviceView.swift',
    root / 'GhostStream/Devices/QRCodeScannerView.swift',
    root / 'GhostStream/Devices/DevicesView.swift',
    root / 'GhostStream/Devices/PairingService.swift',
]
for path in paths:
    assert path.exists(), f'missing {path.relative_to(root)}'

text = '\n'.join(path.read_text() for path in paths)

for required in (
    'Scan QR Code',
    'Enter Code Instead',
    'manualCode.count == 6',
    'AVCaptureSession',
    'AVMetadataObject.ObjectType.qr',
    'claim(qrPayload:',
    'claim(code:',
    'approve(pairingID:',
    'Approve Device',
    'expiresAt',
):
    assert required in text, f'missing pairing UI behavior: {required}'

for forbidden in ('providerPassword', 'playlistBody', 'authorizationHeader'):
    assert forbidden not in text, f'pairing UI exposes forbidden secret field: {forbidden}'

shell = (root / 'GhostStream/Shell/GhostStreamShellView.swift').read_text()
assert 'DevicesView()' in shell, 'Devices tab is not wired to the real pairing screen'
print('ghoststream2 pairing UI contract: PASS')
