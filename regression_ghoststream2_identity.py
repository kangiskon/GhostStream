from pathlib import Path

root = Path(__file__).parent
session = root / 'GhostStream/Account/SessionVault.swift'
identity = root / 'GhostStream/Devices/DeviceIdentityService.swift'
models = root / 'GhostStream/Devices/DeviceModels.swift'

for path in (session, identity, models):
    assert path.exists(), f'missing {path.relative_to(root)}'

combined = '\n'.join(path.read_text() for path in (session, identity, models))
assert 'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' in combined
assert 'Curve25519.KeyAgreement.PrivateKey' in combined
assert 'publicKey' in combined
assert 'UserDefaults' not in identity.read_text(), 'device identity must not use UserDefaults'
assert 'privateKey' not in models.read_text(), 'DeviceIdentity model must not expose a private key'
assert 'refreshToken' in session.read_text()
print('ghoststream2 identity contract: PASS')
