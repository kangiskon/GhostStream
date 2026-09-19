from pathlib import Path
root=Path(__file__).parent
p=(root/'GhostStream/Views/PlayerView.swift').read_text()
s=(root/'GhostStream/Views/SeriesView.swift').read_text()
t=(root/'GhostStreamTV/TVRootView.swift').read_text()
checks={
'iOS resume store':'VODResumeStore' in p,
'iOS speed':'playbackRate' in p,
'iOS fit fill':'aspectFill' in p and 'videoGravity' in p,
'iOS audio tracks':'PlayerMediaTrack' in p and 'audioTracks' in p,
'iOS subtitle tracks':'subtitleTracks' in p,
'iOS AV media selection':'loadMediaSelectionGroup(for:' in p and 'item.select(' in p,
'iOS VLC audio':'audioTrackNames' in p and 'currentAudioTrackIndex' in p,
'iOS VLC subtitles':'videoSubTitlesNames' in p and 'currentVideoSubTitleIndex' in p,
'series context':'SeriesPlaybackContext' in p and 'seriesContext:' in s,
'tv player chrome auto-hide':'revealPlayerChrome' in t and 'chromeHideWorkItem' in t,
'tv episode navigation':'TVSeriesPlaybackContext' in t and 'tvAdjacent' in t and 'tvSwitch' in t,
}
failed=[k for k,v in checks.items() if not v]
if failed:
 print('FAIL'); [print(' -',x) for x in failed]; raise SystemExit(1)
print('PASS')
