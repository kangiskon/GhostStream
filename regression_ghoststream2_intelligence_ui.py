from pathlib import Path

root = Path(__file__).parent
paths = [
    root / 'GhostStream/Intelligence/SourceIntelligenceView.swift',
    root / 'GhostStream/Intelligence/SourceHealthDetailView.swift',
    root / 'GhostStream/Intelligence/DiagnosticHistoryView.swift',
    root / 'GhostStream/Intelligence/DiagnosticHistoryStore.swift',
    root / 'GhostStream/Sync/SyncEngine.swift',
]
for path in paths:
    assert path.exists(), f'missing {path.relative_to(root)}'

text = '\n'.join(path.read_text() for path in paths)
for required in (
    'Health Score',
    'Online',
    'Last Checked',
    'Response Time',
    'Latency',
    'Bitrate',
    'Resolution',
    'Video Codec',
    'Audio Codec',
    'Container',
    'History',
    'Recommendations',
    'Run Diagnostics',
    'DiagnosticSanitizer.sanitize',
    'enqueueDiagnostic',
):
    assert required in text, f'missing Source Intelligence UI behavior: {required}'

shell = (root / 'GhostStream/Shell/GhostStreamShellView.swift').read_text()
assert 'SourceIntelligenceView()' in shell, 'Intelligence tab is not wired to the full dashboard'
print('ghoststream2 Source Intelligence UI contract: PASS')
