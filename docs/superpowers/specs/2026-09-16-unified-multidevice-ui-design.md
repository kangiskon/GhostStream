# GhostStream Unified iPhone / iPad / Apple TV UI Design

Date: 2026-09-16
Status: Approved design, pending implementation plan

## Goal

Make GhostStream feel like one product across iPhone, iPad, and Apple TV while preserving device-appropriate navigation and input. Apple TV remains the visual reference. iPhone keeps touch-first bottom navigation, iPad adopts TV-style top navigation, and tvOS keeps Siri Remote focus behavior.

The implementation must preserve the existing provider/source model, Xtream/M3U parsing, EPG, favorites, resume data, AVPlayer/VLCKit fallback, Series episode-transition safeguards, and tvOS stability fixes.

## Product Principles

1. One visual identity: black/purple GhostStream theme, consistent typography, cards, hero artwork, category chips, media rows, and player chrome.
2. Device-native interaction: touch on iPhone/iPad, focus/Siri Remote on Apple TV.
3. Shared data/playback behavior: source loading, categories, EPG, favorites, resume, audio/subtitle tracks, and compatibility playback remain common.
4. No regression to Apple TV: existing tvOS Home, Live preview, source dismissal, menu cleanup, overlay auto-hide, and episode-switch protections stay intact.
5. No unnecessary iPhone complexity: iPhone keeps bottom navigation and avoids automatic live preview while scrolling.

## Navigation

### iPhone

Use a five-item bottom navigation bar:
- Home
- Live
- Movies
- Series
- Sources

Settings moves behind a gear button in the Home/navigation chrome rather than consuming a primary tab.

Selecting content opens detail/player screens through the existing navigation stack. Back navigation uses standard iOS gestures/buttons.

### iPad

Use a TV-style top navigation bar:
- Home
- Live TV
- Movies
- Series
- Sources

There is no persistent left sidebar. Destinations use the full iPad canvas. Detail screens and nested flows provide a clear Back button. Layout must work in portrait and landscape.

### Apple TV

Retain the current tvOS top navigation and focus model. Do not rework the tvOS shell except where shared visual components can be adopted without changing established behavior.

## Home

All platforms use the same GhostStream visual language:
- black/purple galactic hero
- GhostStream branding
- Continue Watching row
- Live TV row/categories
- Movies row
- Series row

### iPhone Home

Compact stacked version of the TV Home:
- hero reduced for phone height
- horizontal content rows
- bottom navigation remains visible
- gear button for Settings

### iPad Home

Wide TV-inspired layout:
- full-width hero
- top navigation
- wider content rows
- more cards visible per row
- touch-optimized spacing instead of tvOS focus spacing

## Live TV

### Shared behavior

- Full provider category names should be readable; avoid aggressive ellipsis.
- Current/next EPG appears when available.
- Favorites remain accessible.
- Selecting Play opens full-screen playback.
- Existing AVPlayer -> VLCKit compatibility logic remains unchanged unless needed for shared UI wiring.

### iPhone Live Preview

Do not auto-start preview while scrolling.

Flow:
1. User taps a channel.
2. A channel preview/details state opens.
3. User can Play to enter full-screen playback.
4. Preview may be muted by default to avoid unexpected audio.

This avoids bandwidth churn and accidental stream launches during phone scrolling.

### iPad Live Preview

Use TV-style Live browser adapted for touch:
- categories and channels use the larger canvas
- selecting/highlighting a channel schedules a muted preview after a short delay (~0.75s)
- changing selection cancels the previous pending preview
- preview stops on leaving Live
- Play opens full-screen playback

### Apple TV Live Preview

Keep the existing muted focus-delayed preview behavior.

## Movies / VOD

Shared presentation:
- TV-style poster cards
- top category/filter controls
- favorites
- movie details
- Play / Resume
- existing AVPlayer/VLCKit playback stack
- real audio/subtitle tracks
- playback speed, fit/fill, seek, restart, resume

Responsive grid targets:
- iPhone: 2 columns on narrow devices, 3 where width permits
- iPad: 4-6 columns based on available width
- tvOS: preserve current layout

## Series

Shared presentation:
- TV-style series cards
- series detail page
- season selector
- episode list/grid
- Previous Episode
- Next Episode
- Auto-play next episode
- per-episode resume
- episode information

Playback requirements:
- keep two-phase episode transition protection
- never retarget a live VLC player to a new episode URL in place
- old callbacks must be ignored after teardown
- player UI auto-hides after inactivity
- no persistent title clutter over video

## Sources

Use consistent GhostStream styling across platforms while keeping input appropriate to device.

- Xtream/provider login and M3U support remain.
- Saved sources remain.
- Active source state remains shared.
- Source validation/loading behavior remains unchanged.
- tvOS successful source load continues to dismiss the Sources sheet automatically.

On iPhone/iPad, forms are touch-first and use standard text input. iPad centers/widens the form without forcing phone-width cards.

## Settings

Settings use the same card/section visual language.

- iPhone: gear entry from Home/navigation chrome.
- iPad: gear or settings destination from top-level Home/navigation chrome.
- tvOS: preserve current settings behavior.

## Shared Design Components

Create or consolidate reusable SwiftUI components where practical:
- GhostStream theme tokens/colors
- hero/banner
- media artwork/poster card
- media row
- category chip
- empty/loading states
- EPG summary
- Live preview container
- playback chrome styling
- top navigation styling

The shared components must expose layout/input configuration rather than contain device checks everywhere. Platform-specific wrappers may decide sizing, navigation, and focus/touch behavior.

## Data Flow

Existing models/services remain the source of truth:
- SourceStore: active/saved source
- LibraryViewModel: channels, movies, series, categories
- EPGService: now/next data
- existing favorites/resume persistence
- AVPlayer/VLCKit player state

UI screens should not duplicate provider-fetching logic. New preview views receive the selected Channel and use existing playback URL logic.

## Error Handling

- Preview failures must not block browsing.
- A failed preview should show a small unavailable/error state and allow full playback attempt.
- Source load errors remain visible but must not leave stale loading overlays.
- Player errors preserve native -> compatibility fallback behavior.
- Series detail must not reintroduce stale provider-login errors after returning from playback.

## Performance

- Cancel delayed Live preview work when selection changes.
- Avoid starting a stream for every scroll/focus event.
- Reuse artwork caching already present in the project.
- Do not duplicate provider library fetches per platform screen.
- Preserve current player teardown behavior to avoid VLC/AVPlayer resource leaks.

## Accessibility / Interaction

- iPhone/iPad controls keep adequate touch targets.
- iPad supports portrait and landscape.
- tvOS keeps focus-visible controls and Siri Remote navigation.
- Text should scale/truncate gracefully without hiding category meaning.

## Testing / Regression Requirements

Add/maintain automated source-level regressions for:

1. iPhone retains bottom navigation.
2. iPad uses top navigation and no persistent left sidebar.
3. tvOS top navigation/focus behavior is not changed unexpectedly.
4. iPhone Live does not auto-preview while scrolling; preview requires selection/tap.
5. iPad Live preview uses delayed muted preview and cancels stale requests.
6. Full category names are readable on iPhone/iPad.
7. Movies/Series grids adapt by width.
8. VOD audio/subtitle APIs remain present.
9. Series Previous/Next two-phase transition protections remain present.
10. Player chrome auto-hide remains intact where implemented.
11. Source loading and saved-source flows still work.
12. Swift source parses cleanly.
13. Existing Xcode project and bundled VLCKit regression checks still pass.

Final runtime verification must be performed in Xcode on:
- iPhone simulator/device
- iPad simulator/device in portrait and landscape
- Apple TV simulator/device

## Non-Goals

- Do not redesign Apple TV again.
- Do not change provider APIs or source formats.
- Do not replace AVPlayer/VLCKit engines.
- Do not add account/cloud sync in this pass.
- Do not create separate App Store apps for iPhone and iPad; keep the universal iOS target.
