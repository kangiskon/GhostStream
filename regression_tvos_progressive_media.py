from pathlib import Path
p = Path('GhostStreamTV/TVRootView.swift')
s = p.read_text()
required = [
    'final class TVImageLoader: ObservableObject',
    'httpMaximumConnectionsPerHost = 4',
    'NSCache<NSURL, UIImage>',
    'TVRemoteImage',
    'visibleMovieLimit',
    'visibleSeriesLimit',
    'prefix(visibleMovieLimit)',
    'prefix(visibleSeriesLimit)',
    'TVMediaPaging.nextLimit',
]
missing = [x for x in required if x not in s]
if missing:
    raise SystemExit('FAIL missing performance features: ' + ', '.join(missing))
# Media cards should no longer use raw AsyncImage, which bypasses our bounded pipeline.
card_region = s[s.index('private struct TVArtwork'):s.index('private struct TVLiveChannelCard')]
if 'AsyncImage' in card_region:
    raise SystemExit('FAIL TVArtwork still uses AsyncImage')
print('PASS: tvOS progressive paging and cached image pipeline')
