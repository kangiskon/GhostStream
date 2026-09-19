# GhostStream iPhone/iPad performance upgrade — Xcode 26.6

This is the existing universal iPhone/iPad and Apple TV source project, **not** a compiled IPA or tvOS binary. The Apple TV source, Xcode project definitions and bundled VLC frameworks were not changed.

## Implemented

- After a successful Xtream refresh, save a versioned seven-day, provider-identity-checked **metadata-only** library snapshot under `Caches/GhostStreamLibrary`. On a later load, show this snapshot before authentication/provider list requests complete. Refresh continues from the real provider; a cached list is **not** accepted as proof that a newly chosen account is valid.
- Never persist channel/movie playback URLs, direct URLs, or logo/poster URLs in this snapshot: those may contain provider credentials or access tokens. Regenerate standard Xtream playback URLs only in memory from the selected source. Snapshots use file protection, are excluded from iCloud backup, are size-bounded at 32 MiB, and are invalidated when a source is edited or removed.
- Snapshot caching is **Xtream only**. M3U playlists may include login tokens inside each URL, so this update deliberately does not write them into a plain JSON disk cache.
- Compute Live category counts once per library refresh instead of filtering the full channel list once for every category row.
- Keep Movies/Series lazy grids and render 48 items initially, incrementally loading 48 more when the user reaches the end; the existing Load more button remains as a fallback.
- Downsample poster artwork off the main actor into an image memory cache capped at 48 MiB/180 entries. Visible item tasks are cancelable. Artwork URLs are not persisted in the new cache.
- Fetch short EPG only for the selected/previewed Live channel instead of starting a separate provider request for every row shown during scrolling. Cancel pending iPad previews on selection/source/search changes, when leaving Live, and when backgrounding; preview stays muted.
- Discard late provider/EPG responses after the user changes the source; avoid overwriting the next source with previous-source data.
- Show a Home status label while a cached library is being refreshed or when a refresh failed and old cached content is displayed.

## Limitations and checks

- Artwork is a memory cache, not an offline image catalog; after restarting, posters download again. Cached metadata may show blank artwork until the provider refresh completes.
- Cached standard movie URLs may not match an unusual provider-supplied direct playback URL until fresh provider data arrives. Refresh must complete before relying on those provider-specific URLs.
- AVPlayer buffering settings, VLC fallback, Series episode switching, app navigation and the tvOS source were **not changed**. Playback startup remains dependent on codecs, provider and connection quality.
- No live provider throughput or device-level startup timings were available in this environment, so no measured speedup is claimed.
- Swift syntax, Xcode-project static checks, credential-safe model roundtrip and applicable regressions were run. **Apple's `xcodebuild`, device playback and App Store review were not performed** here. Open the project in Xcode 26.6, select the iPhone/iPad target, build and test cold/warm library loads and playback on your own devices.
