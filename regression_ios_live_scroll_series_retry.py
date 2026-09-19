"""Regression contracts for Live scrolling and intermittent Series API failures.

Static checks are not substitutes for Instruments and a device-side Xcode build.
"""
from pathlib import Path
root = Path(__file__).parent
live = (root / 'GhostStream/Views/LiveView.swift').read_text()
rootview = (root / 'GhostStream/Views/RootTabView.swift').read_text()
series = (root / 'GhostStream/Views/SeriesView.swift').read_text()
library = (root / 'GhostStream/Services/LibraryViewModel.swift').read_text()
client = (root / 'GhostStream/Services/XtreamClient.swift').read_text()

# Both Live browsers must window the row builders instead of evaluating an entire
# provider's channel list in SwiftUI ForEach, then expand on last-row appearance.
assert 'private let livePageSize = 64' in live
assert 'Array(allPadChannels.prefix(visibleChannelLimit))' in live
assert 'Array(allChannels.prefix(visibleChannelLimit))' in live
assert 'private func showNextChannelPage' in live
assert 'visibleChannelLimit = livePageSize' in live
assert '.onChange(of: searchText)' in live
assert '.onChange(of: selectedCategory)' in live
assert '.onChange(of: segment)' in live
# Large logos must be decoded as bounded-size thumbnails instead of AsyncImage.
logo = live.split('struct LogoThumb: View', 1)[1].split('struct EmptySourcePrompt', 1)[0]
assert 'GhostCachedPosterImage(url: url, targetWidth: 42' in logo
assert 'AsyncImage' not in logo
assert 'var contentMode: ContentMode = .fill' in rootview

# Use the exact base found during successful library authentication for the
# follow-up series info endpoint; never persist the resolved URL/credentials.
assert 'private(set) var resolvedProviderBaseURL: String?' in library
assert 'resolvedProviderBaseURL = resolved.baseURL' in library
assert 'resolvedProviderBaseURL = nil' in library
assert 'library.resolvedProviderBaseURL ?? server' in series
# A one-off provider HTTP 404 retries once, with cancellation and no infinite loop.
assert 'func seriesInfo(seriesId: Int)' in client
assert 'catch XtreamError.http(404)' in client
assert 'try await Task.sleep(nanoseconds: 350_000_000)' in client
assert 'try Task.checkCancellation()' in client
# An actual persistent error should be recoverable without navigating out.
assert 'Button("Retry")' in series
assert 'errorMessage = nil' in series
print('PASS Live scroll windowing, thumbnail reuse, and Series 404 recovery contracts')
