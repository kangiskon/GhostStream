from pathlib import Path
import plistlib

root = Path('.')
view = (root/'GhostStreamTV/TVRootView.swift').read_text()
lib = (root/'GhostStreamTV/Shared/LibraryViewModel.swift').read_text()
models = (root/'GhostStreamTV/Shared/Models.swift').read_text()

checks = {
    'paging policy': 'enum TVMediaPaging' in models and 'initialLimit = 60' in models and 'increment = 36' in models,
    'movie progressive window': 'prefix(visibleMovieLimit)' in view and 'visibleMovieLimit' in view,
    'series progressive window': 'prefix(visibleSeriesLimit)' in view and 'visibleSeriesLimit' in view,
    'bounded image connections': 'httpMaximumConnectionsPerHost = 4' in view,
    'decoded image cache': 'NSCache<NSURL, UIImage>' in view and 'totalCostLimit = 96 * 1024 * 1024' in view,
    'network image cache': 'diskCapacity: 256 * 1024 * 1024' in view,
    'no raw AsyncImage': 'AsyncImage' not in view,
    'movie genre background builder': 'buildMovieGenreIndex' in lib and 'await Task.yield()' in lib,
    'series genre background builder': 'buildSeriesGenreIndex' in lib,
    'movies publish before movie genre result': lib.find('self.movies = vod.items') < lib.find('self.movieGenreBuckets = movieIndex.buckets'),
    'series publish before series genre result': lib.find('self.series = ser.items') < lib.find('self.seriesGenreBuckets = seriesIndex.buckets'),
    'clean live layout retained': 'liveGridColumns' in view and 'TVLiveChannelCard' in view,
    'portrait poster layout retained': 'posterGridColumns' in view and 'TVPosterCard' in view,
}
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if not all(checks.values()):
    raise SystemExit(1)

with (root/'GhostStreamTV/Info.plist').open('rb') as f:
    plist = plistlib.load(f)
if plist.get('CFBundleExecutable') != '$(EXECUTABLE_NAME)':
    raise SystemExit('FAIL: tvOS CFBundleExecutable regression')
print('PASS: tvOS bundle executable')
