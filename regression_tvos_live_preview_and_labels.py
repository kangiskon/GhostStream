from pathlib import Path

p = Path('GhostStreamTV/TVRootView.swift')
s = p.read_text()

checks = {
    'player title removed from nav': '.navigationTitle(effectiveTitle)' not in s,
    'compatibility player title label removed': 'Text(effectiveTitle).font(.headline)' not in s,
    'live preview state exists': '@State private var previewChannel: Channel?' in s,
    'live preview uses delayed focus scheduling': 'schedulePreview(for:' in s and 'previewWorkItem' in s,
    'live preview is muted': 'player.isMuted = true' in s,
    'category sidebar widened': '.frame(width: 420)' in s,
    'category labels can wrap': '.lineLimit(2)' in s and 'TVLiveSidebarChip' in s,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('FAIL: ' + '; '.join(failed))
print('PASS: tvOS live preview/category/title regression')
