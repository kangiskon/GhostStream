from pathlib import Path
p = Path('GhostStream/Views/PlayerView.swift')
s = p.read_text()
checks = {
    'native live aspect fit': 'parent.kind == .live ? .resizeAspect : .resizeAspectFill' in s,
    'live info is confined to controls overlay': 'if controlsVisible {' in s and 'private var liveMockupOverlay' in s,
    'tracks playback start': 'hasPlaybackStarted = true' in s,
    'compatibility live fit mode': 'kind == .live ? .scaleAspectFit : .scaleAspectFill' in s,
}
for name, ok in checks.items():
    print(f'{name}: {"PASS" if ok else "FAIL"}')
if not all(checks.values()):
    raise SystemExit(1)
