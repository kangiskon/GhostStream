"""Performance/safety contracts for the universal iPhone/iPad target only.
Static checks do not replace running xcodebuild and an instrumented device test.
"""
from pathlib import Path
root = Path(__file__).parent
library = (root/'GhostStream/Services/LibraryViewModel.swift').read_text()
models = (root/'GhostStream/Models/Models.swift').read_text()
app = (root/'GhostStream/GhostStreamApp.swift').read_text()
source_store = (root/'GhostStream/Services/SourceStore.swift').read_text()
rootview = (root/'GhostStream/Views/RootTabView.swift').read_text()
live = (root/'GhostStream/Views/LiveView.swift').read_text()
movies = (root/'GhostStream/Views/MoviesView.swift').read_text()
series = (root/'GhostStream/Views/SeriesView.swift').read_text()
tv = (root/'GhostStreamTV/TVRootView.swift').read_text()

# Cache is a bounded, local metadata snapshot, scoped to a provider identity.
assert 'actor LibrarySnapshotCache' in library
assert 'FileManager.default.urls(for: .cachesDirectory' in library
assert 'fingerprint' in library and 'SHA256.hash' in library
assert 'source.kind == .xtream' in library, 'Never cache M3U URLs with embedded tokens'
assert 'url = ""' in library and 'directSource = nil' in library
assert 'icon = nil' in library and 'cover = nil' in library
assert 'await snapshotCache.read(for: source)' in library
assert 'loadGeneration' in library and 'generation == loadGeneration' in library
assert 'loadM3U(source: source, generation: generation)' in library
assert 'guard generation == loadGeneration else { throw CancellationError() }' in library
assert 'cacheSnapshot' in library and 'Task.detached(priority: .utility)' in library
assert 'invalidateLibraryCache(for: source.id)' in source_store
assert 'private func invalidateLibraryCache(for id: UUID)' in source_store
for typename in ('Channel', 'Category', 'VODStream', 'Series'):
    assert f'struct {typename}: Codable,' in models

# Repeated category count calls should use a built-once index, not per-row filters.
assert 'liveCategoryCounts' in library
assert 'library.channelCount(in: category)' in live
assert 'library.channels(in: category).count' not in live

# Artwork fetch and thumbnail decode should be cancelable and bounded in memory.
assert 'actor GhostPosterMemoryCache' in rootview
assert 'CGImageSourceCreateThumbnailAtIndex' in rootview
assert 'totalCostLimit = 48 * 1024 * 1024' in rootview
assert 'GhostCachedPosterImage' in rootview
assert 'AsyncImage(url: url)' not in rootview[rootview.index('struct GhostPosterCard:'):rootview.index('struct GhostMediaRail')]

# Preview pending requests are canceled when changing sources/searching or leaving.
assert '.onChange(of: store.activeSourceID)' in live
assert '.onChange(of: searchText)' in live
assert 'previewWorkItem?.cancel()' in live
assert 'func stop()' in live
assert '.task(id: channel.streamId)' not in live, 'Per-row EPG requests overwhelm providers when a list scrolls'
assert '.task(id: selectedPreviewChannel?.streamId)' in live
assert 'UIApplication.didEnterBackgroundNotification' in live

# Existing paging retained and tvOS source is not rewritten by iOS optimization.
assert 'visibleLimit' in movies and 'visibleLimit' in series
assert 'let page = Array(filtered.prefix(visibleLimit))' in movies
assert 'let page = Array(filtered.prefix(visibleLimit))' in series
assert '.onAppear {' in movies and '.onAppear {' in series
assert 'TVGhostHomeHero' in tv and 'episodeSwitchInProgress' in tv
assert 'UIDevice.current.userInterfaceIdiom == .pad' in rootview
assert 'TabView(selection:' in rootview
assert 'if let notice = library.refreshNotice' in rootview
print('PASS iOS performance + cache safety contracts')
