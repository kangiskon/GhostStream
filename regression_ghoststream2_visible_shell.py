from pathlib import Path

root = Path(__file__).parent
shell = (root / 'GhostStream/Shell/GhostStreamShellView.swift').read_text()
dashboard = (root / 'GhostStream/Dashboard/GhostDashboardView.swift').read_text()

for literal in (
    '"(library.channels.count)"',
    '"(library.movies.count)"',
    '"(library.series.count)"',
    '"(device.platform.uppercased()) • (device.trustState.capitalized)"',
    '"(counts.live)"',
    '"(counts.movies)"',
    '"(counts.series)"',
    '"(accountStore.devices.filter { $0.revokedAt == nil }.count)"',
    '"(counts.total) library items available across this device."',
):
    assert literal not in shell + dashboard, f'visible placeholder leaked into GhostStream 2 shell: {literal}'

for expected in (
    r'\(library.channels.count)',
    r'\(library.movies.count)',
    r'\(library.series.count)',
    r'\(device.platform.uppercased())',
    r'\(counts.live)',
    r'\(counts.movies)',
    r'\(counts.series)',
    r'\(counts.total)',
):
    assert expected in shell + dashboard, f'missing Swift interpolation: {expected}'

print('ghoststream2 visible shell interpolation: PASS')
