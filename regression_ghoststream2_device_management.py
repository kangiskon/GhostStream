from pathlib import Path

root = Path(__file__).parent
devices = root / 'GhostStream/Devices/DevicesView.swift'
detail = root / 'GhostStream/Devices/DeviceDetailView.swift'
account = root / 'GhostStream/Account/AccountStore.swift'

for path in (devices, detail, account):
    assert path.exists(), f'missing {path.relative_to(root)}'

text = devices.read_text() + '\n' + detail.read_text() + '\n' + account.read_text()

for required in (
    'Trusted',
    'Last Seen',
    'Sync Status',
    'Source Credentials',
    'Rename Device',
    'Revoke Device',
    'Send Source',
    'renameDevice',
    'revokeDevice',
    'CredentialTransferService',
):
    assert required in text, f'missing device-management behavior: {required}'

print('ghoststream2 device management contract: PASS')
