from pathlib import Path
p=Path('GhostStream/Views/PlayerView.swift').read_text()
s=Path('GhostStream/Views/SeriesView.swift').read_text()
checks={
 'track model':'struct PlayerMediaTrack' in p,
 'audio selector':'Audio Language' in p,
 'subtitle selector':'Subtitles / CC' in p,
 'speed':'Playback Speed' in p,
 'restart':'Restart' in p,
 'skip back':'gobackward.10' in p,
 'skip forward':'goforward.10' in p,
 'resume store':'VODResumeStore' in p,
 'series context':'SeriesPlaybackContext' in p,
 'next episode':'Next Episode' in p,
 'previous episode':'Previous Episode' in p,
 'autoplay':'Auto-play Next' in p,
 'episode info':'Episode Info' in p,
 'series passes context':'seriesContext:' in s,
 'av async media selection':'loadMediaSelectionGroup(for:' in p,
 'no deprecated av media selection':'mediaSelectionGroup(forMediaCharacteristic:' not in p,
 'vlc audio tracks':'audioTrackNames' in p,
 'vlc subtitles':'videoSubTitlesNames' in p,
}
failed=[k for k,v in checks.items() if not v]
if failed:
 print('FAIL:', ', '.join(failed)); raise SystemExit(1)
print('PASS: VOD player feature regression')
