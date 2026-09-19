from pathlib import Path
p = Path('/mnt/data/tv_playback_debug/GhostStreamTV/TVRootView.swift')
s = p.read_text()
checks = {
    'TVVLCKit conditional import': '#if canImport(TVVLCKit)' in s and 'import TVVLCKit' in s,
    'HLS candidate conversion': '.m3u8' in s and 'hasSuffix(".ts")' in s,
    'native failure detection': 'case .failed:' in s,
    'compatibility fallback state': 'useCompatibilityEngine' in s,
    'final native failure state': 'nativeAttemptsExhausted = true' in s,
    'AVKit native controller': 'AVPlayerViewController' in s,
}
failed = [k for k,v in checks.items() if not v]
for k,v in checks.items(): print(('PASS' if v else 'FAIL'), k)
raise SystemExit(1 if failed else 0)
