from pathlib import Path
p=Path('GhostStreamTV/TVRootView.swift').read_text()
checks=['TVSeriesPlaybackContext','Audio / Subtitles','Previous Episode','Next Episode','Season / Episode','audioTrackNames','videoSubTitlesNames','TVNativePlayerController']
miss=[x for x in checks if x not in p]
if miss: print('FAIL:', ', '.join(miss)); raise SystemExit(1)
print('PASS: tvOS VOD options regression')
