from pathlib import Path

root = Path(__file__).parent
ios_env = root / 'GhostStream/Devices/CredentialEnvelope.swift'
ios_service = root / 'GhostStream/Devices/CredentialTransferService.swift'
tv_env = root / 'GhostStreamTV/Shared/CredentialEnvelope.swift'
tv_service = root / 'GhostStreamTV/Shared/CredentialTransferService.swift'
harness = root / 'CredentialEnvelopeRegression.swift'

for path in (ios_env, ios_service, tv_env, tv_service, harness):
    assert path.exists(), f'missing {path.relative_to(root)}'

text = '\n'.join(path.read_text() for path in (ios_env, ios_service, tv_env, tv_service, harness))

for required in (
    'Curve25519.KeyAgreement.PrivateKey',
    'sharedSecretFromKeyAgreement',
    'hkdfDerivedSymmetricKey',
    'ChaChaPoly.seal',
    'ChaChaPoly.open',
    'senderDeviceID',
    'recipientDeviceID',
    'authenticatedData',
    'ephemeralPublicKey',
    'recipientPrivateKey',
    'wrong private key',
):
    assert required in text, f'missing encrypted transfer behavior: {required}'

for forbidden in ('print(payload', 'print(source.password', 'NSLog'):
    assert forbidden not in text, f'plaintext credential logging is forbidden: {forbidden}'

print('ghoststream2 credential crypto contract: PASS')
