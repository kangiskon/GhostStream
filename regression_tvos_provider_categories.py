from pathlib import Path
import plistlib

root = Path(__file__).resolve().parent
models = (root/'GhostStreamTV/Shared/Models.swift').read_text()
vm = (root/'GhostStreamTV/Shared/LibraryViewModel.swift').read_text()
ui = (root/'GhostStreamTV/TVRootView.swift').read_text()
client = (root/'GhostStreamTV/Shared/XtreamClient.swift').read_text()

# Provider APIs are still the source of truth.
for action in ('get_live_categories','get_vod_categories','get_series_categories'):
    assert action in client, action

# Real category IDs are indexed once and exposed as O(1) lookups.
for symbol in ('ProviderCategoryIndex','liveBuckets(items:','movieBuckets(items:','seriesBuckets(items:','nonEmptyCategories'):
    assert symbol in models, symbol
for symbol in ('liveCategoryBuckets','movieCategoryBuckets','seriesCategoryBuckets','func movies(in category: Category?)','func shows(in category: Category?)'):
    assert symbol in vm, symbol

# tvOS presentation uses provider categories, not the former standard-genre rail.
assert 'TVProviderCategoryStrip' in ui
assert '@State private var selectedMovieCategory: Category?' in ui
assert '@State private var selectedSeriesCategory: Category?' in ui
assert 'library.movieCategories' in ui
assert 'library.seriesCategories' in ui
assert 'library.liveCategories' in ui
assert 'StandardMediaGenre' not in ui
assert 'TVGenreStrip' not in ui
assert 'movieGenreBuckets' not in ui
assert 'seriesGenreBuckets' not in ui

# Progressive paging and cached artwork remain intact.
assert 'TVMediaPaging.initialLimit' in ui
assert 'TVImageLoader' in ui
assert 'httpMaximumConnectionsPerHost = 4' in ui

# Bundle still has a valid executable declaration.
with (root/'GhostStreamTV/Info.plist').open('rb') as f:
    plist = plistlib.load(f)
assert plist.get('CFBundleExecutable') == '$(EXECUTABLE_NAME)'

print('tvOS provider-category regression passed')
