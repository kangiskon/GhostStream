from pathlib import Path
p = Path('/mnt/data/tv_ui_rebuild/GhostStreamTV/TVRootView.swift')
s = p.read_text()
checks = {
    'dedicated live card': 'private struct TVLiveChannelCard' in s,
    'dedicated poster card': 'private struct TVPosterCard' in s,
    'live 16:9 artwork': 'aspectRatio(16.0 / 9.0' in s,
    'poster 2:3 artwork': 'aspectRatio(2.0 / 3.0' in s,
    'live title clamped': 'lineLimit(2)' in s and 'TVLiveChannelCard' in s,
    'poster title clamped': 'TVPosterCard' in s and 'lineLimit(2)' in s,
    'live adaptive grid': 'liveGridColumns' in s,
    'poster adaptive grid': 'posterGridColumns' in s,
    'compact genre chip': 'minHeight: 62' in s or 'height: 62' in s,
    'no flexible 6-column movie grid': 'Array(repeating: GridItem(.flexible(), spacing: 28), count: 6)' not in s,
    'no flexible 5-column live grid': 'Array(repeating: GridItem(.flexible(), spacing: 28), count: 5)' not in s,
    'media links use plain style': s.count('.buttonStyle(.plain)') >= 3,
}
failed = [k for k,v in checks.items() if not v]
if failed:
    print('FAIL:', ', '.join(failed))
    raise SystemExit(1)
print('PASS: tvOS media layouts use bounded live cards, portrait posters, and compact categories')
