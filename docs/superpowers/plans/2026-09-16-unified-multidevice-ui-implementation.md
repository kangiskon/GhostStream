# GhostStream Unified Multidevice UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the universal iPhone/iPad GhostStream app visually and behaviorally match the established Apple TV experience while preserving touch-native navigation, existing playback engines, provider/source logic, and tvOS stability.

**Architecture:** Keep the existing iOS and tvOS targets and existing data/player services. Port the tvOS black/purple visual language and Home/Live/Movies/Series structure into the iOS SwiftUI screens, with iPhone using bottom tabs and tap-driven Live preview, iPad using TV-style top navigation plus delayed muted Live preview, and tvOS left behaviorally unchanged. Reuse the current iOS player and provider models; only presentation/navigation/preview wiring changes.

**Tech Stack:** Swift 5 / SwiftUI, UIKit, AVKit/AVFoundation, MobileVLCKit, TVVLCKit, Xcode 26.x universal iOS target + tvOS target, Python source-level regression scripts.

**Spec:** `docs/superpowers/specs/2026-09-16-unified-multidevice-ui-design.md`

## Global Constraints

- Keep one universal iOS app target for iPhone and iPad; do not create a separate iPad app.
- iPhone keeps bottom navigation: Home / Live / Movies / Series / Sources.
- iPad uses top navigation: Home / Live TV / Movies / Series / Sources, with no persistent left sidebar.
- Apple TV keeps its current top navigation, focus model, Live preview, source dismissal, menu cleanup, overlay auto-hide, and episode-switch protections.
- iPhone Live preview starts only after the user selects/taps a channel; it must not auto-start while scrolling.
- iPad Live preview starts muted after approximately 0.75 seconds, cancels stale pending previews, and stops when leaving Live.
- Preserve SourceStore, LibraryViewModel, EPGService, favorites, resume persistence, AVPlayer -> VLCKit fallback, real audio/subtitle APIs, and two-phase Series episode switching.
- Do not change provider APIs, source formats, or playback engines.
- Full category names must remain readable without aggressive one-line ellipsis.
- iPad must work in portrait and landscape.
- Existing tvOS source files are regression-protected and are not redesigned in this pass.

---

## File Structure / Responsibility Map

- `GhostStream/GhostStreamApp.swift` — iOS theme tokens and global UIKit appearance; change cyan tokens to tvOS-matching purple tokens.
- `GhostStream/Views/RootTabView.swift` — iPhone/iPad primary navigation shell, unified Home dashboard, reusable iOS visual components.
- `GhostStream/Views/LiveView.swift` — device-adaptive Live browser, full category labels, phone preview flow, iPad delayed preview panel.
- `GhostStream/Views/MoviesView.swift` — TV-style VOD filtering/grid presentation with phone/iPad column adaptation.
- `GhostStream/Views/SeriesView.swift` — TV-style Series grid/detail/episode presentation with existing episode player context preserved.
- `GhostStream/Views/LauncherView.swift` — Sources destination styling and touch-first source management.
- `GhostStream/Views/SettingsView.swift` — gear-entry Settings screen using the same purple card language.
- `GhostStream/Views/PlayerView.swift` — remove persistent title clutter, keep auto-hide chrome and playback behavior, align controls with unified purple theme.
- `GhostStream/Assets.xcassets/GhostHomeHero.imageset/*` — copy the existing tvOS hero artwork into the iOS asset catalog.
- `GhostStream.xcodeproj/project.pbxproj` — only adjust if asset membership/file references require it; no target restructuring.
- `regression_unified_theme_home.py` — visual-token/Home/navigation source regression.
- `regression_ios_live_preview_unified.py` — phone/iPad Live preview behavior regression.
- `regression_unified_media_layout.py` — Movies/Series responsive grid and category-label regression.
- `regression_unified_sources_player.py` — Sources/Settings/player-chrome regression.
- Existing `regression_tvos_*.py`, `regression_vod_player_*.py`, `regression_xcode265.py`, and `regression_bundled_vlckit.py` remain part of the final gate.

---

### Task 1: Match the iOS Visual Tokens and Hero Asset to Apple TV

**Files:**
- Modify: `GhostStream/GhostStreamApp.swift:48-61`
- Create/copy: `GhostStream/Assets.xcassets/GhostHomeHero.imageset/Contents.json`
- Create/copy: `GhostStream/Assets.xcassets/GhostHomeHero.imageset/ghost-home-hero.png`
- Test: `regression_unified_theme_home.py`

**Interfaces:**
- Consumes: existing `Theme` references used by all iOS views.
- Produces: unchanged `Theme.accent`, `Theme.background`, `Theme.card`, `Theme.card2`, `Theme.muted`, `Theme.border`, `Theme.cardGradient`; new `Theme.accentBright`, `Theme.heroGlow`; image asset named exactly `GhostHomeHero`.

- [ ] **Step 1: Write the failing theme/asset regression**

```python
from pathlib import Path

root = Path(__file__).parent
app = (root / "GhostStream/GhostStreamApp.swift").read_text()
asset = root / "GhostStream/Assets.xcassets/GhostHomeHero.imageset/Contents.json"

assert "124/255" in app and "92/255" in app, "iOS accent must match tvOS purple"
assert "static let accentBright" in app
assert "static let heroGlow" in app
assert asset.exists(), "GhostHomeHero must be present in the iOS asset catalog"
```

- [ ] **Step 2: Run the regression and verify RED**

Run: `python3 regression_unified_theme_home.py`

Expected: FAIL because the iOS `Theme` is still cyan and the iOS `GhostHomeHero.imageset` does not exist.

- [ ] **Step 3: Replace iOS theme tokens with the tvOS black/purple palette**

Use these exact values in `Theme`:

```swift
enum Theme {
    static let accent = Color(red: 124/255, green: 92/255, blue: 1.0)
    static let accentBright = Color(red: 160/255, green: 128/255, blue: 1.0)
    static let background = Color(red: 11/255, green: 11/255, blue: 15/255)
    static let background2 = Color(red: 18/255, green: 12/255, blue: 28/255)
    static let card = Color(red: 17/255, green: 17/255, blue: 22/255)
    static let card2 = Color(red: 28/255, green: 24/255, blue: 44/255)
    static let muted = Color.white.opacity(0.58)
    static let border = accent.opacity(0.34)
    static let cardGradient = LinearGradient(
        colors: [Color(red: 27/255, green: 22/255, blue: 42/255), Color(red: 15/255, green: 15/255, blue: 20/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let heroGlow = LinearGradient(
        colors: [accent.opacity(0.22), accentBright.opacity(0.08), .clear],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}
```

Update `UITabBarAppearance` / `UINavigationBarAppearance` selected tint to the same purple values instead of cyan.

- [ ] **Step 4: Copy the approved tvOS hero asset into iOS**

Run:

```bash
mkdir -p GhostStream/Assets.xcassets/GhostHomeHero.imageset
cp GhostStreamTV/Assets.xcassets/GhostHomeHero.imageset/ghost-home-hero.png \
   GhostStream/Assets.xcassets/GhostHomeHero.imageset/ghost-home-hero.png
cp GhostStreamTV/Assets.xcassets/GhostHomeHero.imageset/Contents.json \
   GhostStream/Assets.xcassets/GhostHomeHero.imageset/Contents.json
```

- [ ] **Step 5: Run the regression and Swift parse**

Run:

```bash
python3 regression_unified_theme_home.py
swiftc -parse GhostStream/GhostStreamApp.swift
```

Expected: PASS / exit 0.

- [ ] **Step 6: Commit**

```bash
git add GhostStream/GhostStreamApp.swift GhostStream/Assets.xcassets/GhostHomeHero.imageset regression_unified_theme_home.py
git commit -m "feat: align iOS GhostStream theme with tvOS"
```

---

### Task 2: Unify iPhone Bottom Tabs, iPad Top Navigation, and Home Dashboard

**Files:**
- Modify: `GhostStream/Views/RootTabView.swift:6-236`
- Test: `regression_unified_theme_home.py`

**Interfaces:**
- Produces: `GhostPrimarySection: Int, CaseIterable, Hashable` with `.home`, `.live`, `.movies`, `.series`, `.sources`.
- Produces: `GhostTopNavigation(selection: Binding<GhostPrimarySection>, onSettings: () -> Void)`.
- Produces: `GhostHomeView(selection: Binding<GhostPrimarySection>, onSettings: () -> Void)`.
- Consumes: existing `SourceStore`, `LibraryViewModel`, `EPGService`, `LauncherView`, `MoviesView`, `SeriesView`, `LiveView`, `SettingsView`.

- [ ] **Step 1: Extend the navigation regression to require the approved device split**

Add to `regression_unified_theme_home.py`:

```python
root_view = (root / "GhostStream/Views/RootTabView.swift").read_text()
assert 'case home, live, movies, series, sources' in root_view
assert 'Label("Sources", systemImage:' in root_view
assert 'UIDevice.current.userInterfaceIdiom == .pad' in root_view
assert 'GhostTopNavigation' in root_view
assert 'TabView(selection:' in root_view
assert 'SettingsView()' in root_view
assert 'Image("GhostHomeHero")' in root_view
```

- [ ] **Step 2: Run and verify RED**

Run: `python3 regression_unified_theme_home.py`

Expected: FAIL because the current iPhone fifth tab is Settings, iPad has only a Back header, and Home still uses the old hero.

- [ ] **Step 3: Replace integer navigation with a typed primary-section enum**

Add near the top of `RootTabView.swift`:

```swift
enum GhostPrimarySection: Int, CaseIterable, Hashable {
    case home, live, movies, series, sources

    var title: String {
        switch self {
        case .home: return "Home"
        case .live: return "Live TV"
        case .movies: return "Movies"
        case .series: return "Series"
        case .sources: return "Sources"
        }
    }
}
```

Change `@State private var selectedTab = 0` to:

```swift
@State private var selectedSection: GhostPrimarySection = .home
@State private var showSettings = false
```

- [ ] **Step 4: Keep iPhone bottom navigation but replace Settings with Sources**

Implement the five primary tabs with tags based on `GhostPrimarySection`. Use `LauncherView()` for `.sources`. Present `SettingsView()` from the Home gear via `.fullScreenCover(isPresented: $showSettings)`.

Required tab labels:

```swift
Label("Home", systemImage: "house.fill")
Label("Live", systemImage: "tv.fill")
Label("Movies", systemImage: "film.fill")
Label("Series", systemImage: "rectangle.stack.fill")
Label("Sources", systemImage: "externaldrive.fill")
```

- [ ] **Step 5: Build the iPad TV-style top navigation with no sidebar**

Add `GhostTopNavigation` to `RootTabView.swift` with horizontally scrollable buttons for all `GhostPrimarySection.allCases` plus a trailing gear button. The iPad shell must be:

```swift
VStack(spacing: 0) {
    GhostTopNavigation(selection: $selectedSection) {
        showSettings = true
    }
    iPadDestination
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

No `NavigationSplitView`, `List` sidebar, or fixed left navigation column may be introduced.

- [ ] **Step 6: Port the tvOS hero composition into the iOS Home dashboard**

Replace the old `GhostHeroExact` Home treatment with `Image("GhostHomeHero")`, a black/purple gradient overlay, GhostStream branding, active-source subtitle, and two prominent actions:

```swift
Button("WATCH LIVE") { selection = .live }
Button("BROWSE LIBRARY") { selection = .movies }
```

Below the hero, keep horizontal rows for Continue Watching-style content, Live, Movies, and Series. iPhone uses compact heights; iPad uses the wider TV-like hero and more cards.

- [ ] **Step 7: Run navigation/Home regression and parse**

Run:

```bash
python3 regression_unified_theme_home.py
swiftc -parse GhostStream/Views/RootTabView.swift
```

Expected: PASS / exit 0.

- [ ] **Step 8: Commit**

```bash
git add GhostStream/Views/RootTabView.swift regression_unified_theme_home.py
git commit -m "feat: unify iPhone and iPad GhostStream navigation"
```

---

### Task 3: Build Device-Adaptive Live TV Browsing and Preview

**Files:**
- Modify: `GhostStream/Views/LiveView.swift:3-445`
- Test: `regression_ios_live_preview_unified.py`

**Interfaces:**
- Produces: `GhostLivePreviewPanel(channel: Channel?, now: EPGProgramme?, next: EPGProgramme?, mode: GhostLivePreviewMode, onPlay: (Channel) -> Void)`.
- Produces: `GhostLivePreviewMode { case phoneTap, padDelayed }`.
- Produces: `GhostLivePreviewPlayer(urlString: String)` using muted AVPlayer only.
- Consumes: `library.channels`, `library.liveCategories`, `EPGService.nowPlaying(channel:)`, `EPGService.upcoming(channel:limit:)`, existing `PlayerView(... kind: .live ...)`.

- [ ] **Step 1: Write the failing Live-preview regression**

Create `regression_ios_live_preview_unified.py`:

```python
from pathlib import Path
p = Path(__file__).parent / "GhostStream/Views/LiveView.swift"
s = p.read_text()

assert "GhostLivePreviewMode" in s
assert "case phoneTap" in s and "case padDelayed" in s
assert "0.75" in s, "iPad preview delay must remain approximately 0.75s"
assert "isMuted = true" in s
assert "previewWorkItem?.cancel()" in s
assert "onDisappear" in s and "stopPreview" in s
assert "lineLimit(2)" in s, "category names must be allowed to wrap"
assert "PlayerView(title:" in s and "kind: .live" in s
```

- [ ] **Step 2: Run and verify RED**

Run: `python3 regression_ios_live_preview_unified.py`

Expected: FAIL because iOS does not yet implement the unified preview panel/player.

- [ ] **Step 3: Keep phone browsing touch-first and preview-on-selection only**

For iPhone, category rows remain vertically scrollable. In a channel list, replace direct full-player navigation with selection state:

```swift
@State private var selectedPreviewChannel: Channel?
```

Tapping a channel sets `selectedPreviewChannel`. Show `GhostLivePreviewPanel` with a Play button; the Play action navigates/presents `PlayerView(title:urlString:kind:epgChannelId:)`. Do not schedule preview from scroll position, `onAppear`, or row visibility.

- [ ] **Step 4: Build the iPad TV-style Live browser**

For iPad width, use a three-area layout:

```swift
HStack(alignment: .top, spacing: 18) {
    categoryColumn      // about 260-320 pt, full names up to 2 lines
    channelColumn       // flexible list
    previewColumn       // about 38-42% of remaining width
}
```

Selecting a channel calls:

```swift
private func schedulePreview(_ channel: Channel) {
    previewWorkItem?.cancel()
    let work = DispatchWorkItem { selectedPreviewChannel = channel }
    previewWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
}
```

Changing channel selection cancels the prior work item. `onDisappear` calls `stopPreview(clearCurrent: true)`.

- [ ] **Step 5: Add a muted native preview player**

Implement `GhostLivePreviewPlayer` as `UIViewRepresentable` backed by `AVPlayerLayer`; set:

```swift
player.isMuted = true
player.automaticallyWaitsToMinimizeStalling = true
```

For `.ts` URLs, try the equivalent `.m3u8` URL for preview only. Preview failure must render an unavailable state and must not prevent the Play button from opening the full `PlayerView`, where the normal AVPlayer -> VLCKit fallback still applies.

- [ ] **Step 6: Make category names readable**

Category controls on both iPhone and iPad use:

```swift
.lineLimit(2)
.minimumScaleFactor(0.80)
.multilineTextAlignment(.leading)
```

Do not use a one-line width that produces `Canada...` / `PBS L...` for ordinary provider category names.

- [ ] **Step 7: Run Live regression and parse**

Run:

```bash
python3 regression_ios_live_preview_unified.py
swiftc -parse GhostStream/Views/LiveView.swift
```

Expected: PASS / exit 0.

- [ ] **Step 8: Commit**

```bash
git add GhostStream/Views/LiveView.swift regression_ios_live_preview_unified.py
git commit -m "feat: add unified Live preview on iPhone and iPad"
```

---

### Task 4: Match Movies and Series to the TV Card/Grid Language

**Files:**
- Modify: `GhostStream/Views/MoviesView.swift:3-94`
- Modify: `GhostStream/Views/SeriesView.swift:4-170`
- Modify: `GhostStream/Views/RootTabView.swift:240-470` for shared card/chip styling used by both screens
- Test: `regression_unified_media_layout.py`

**Interfaces:**
- Consumes: `GhostPosterCard`, `CategoryChips`, `FavoriteButton`, `PlayerView`, `SeriesPlaybackContext`.
- Produces: responsive iPhone Movie/Series grids (2 columns narrow, 3 columns wide), iPad grids (4-6 columns), TV-like purple category chips, TV-like Series detail/episode cards.

- [ ] **Step 1: Write the failing responsive-media regression**

Create `regression_unified_media_layout.py`:

```python
from pathlib import Path
root = Path(__file__).parent
movies = (root / "GhostStream/Views/MoviesView.swift").read_text()
series = (root / "GhostStream/Views/SeriesView.swift").read_text()
root_view = (root / "GhostStream/Views/RootTabView.swift").read_text()

assert "phoneColumnCount" in movies
assert "availableWidth >= 390 ? 3 : 2" in movies
assert "padColumnCount" in movies and "min(6" in movies
assert "phoneColumnCount" in series
assert "availableWidth >= 390 ? 3 : 2" in series
assert "SEASON" in series and "SeriesPlaybackContext" in series
assert "Theme.accentBright" in root_view
```

- [ ] **Step 2: Run and verify RED**

Run: `python3 regression_unified_media_layout.py`

Expected: FAIL because current phone grids are fixed at three columns and shared cards still use the older iOS styling.

- [ ] **Step 3: Update shared poster/category visual treatment**

In the shared iOS components in `RootTabView.swift`, make poster borders, chips, section headers, and card gradients use the exact `Theme.accent`, `Theme.accentBright`, `Theme.border`, and `Theme.cardGradient` tokens created in Task 1. Keep touch controls at least 44 pt high.

- [ ] **Step 4: Make Movie grid width-driven**

In `MoviesView`, calculate:

```swift
let phoneColumnCount = availableWidth >= 390 ? 3 : 2
let padColumnCount = max(4, min(6, Int(availableWidth / 190)))
let columnCount = isPadLike ? padColumnCount : phoneColumnCount
```

Keep Favorites/category/search filtering unchanged and preserve `contentID: String(movie.id)` when navigating to `PlayerView`.

- [ ] **Step 5: Make Series grid width-driven and TV-like**

Use the same phone/iPad column policy in `SeriesView`. Preserve favorites/category/search filtering. In `SeriesDetailView`, use a TV-like header (cover + title + plot + episode count), season chips, and touch-sized episode cards while preserving this exact player handoff:

```swift
PlayerView(
    title: episode.title,
    urlString: episode.url ?? "",
    kind: .vod,
    contentID: episode.id,
    seriesContext: SeriesPlaybackContext(
        seriesTitle: series.name,
        plot: series.plot,
        episodes: episodes,
        initialEpisodeID: episode.id
    )
)
```

- [ ] **Step 6: Run responsive-media regression and parse**

Run:

```bash
python3 regression_unified_media_layout.py
swiftc -parse GhostStream/Views/MoviesView.swift
swiftc -parse GhostStream/Views/SeriesView.swift
swiftc -parse GhostStream/Views/RootTabView.swift
```

Expected: PASS / exit 0.

- [ ] **Step 7: Commit**

```bash
git add GhostStream/Views/MoviesView.swift GhostStream/Views/SeriesView.swift GhostStream/Views/RootTabView.swift regression_unified_media_layout.py
git commit -m "feat: match iOS media browsing to tvOS design"
```

---

### Task 5: Make Sources and Settings Match the Unified GhostStream Shell

**Files:**
- Modify: `GhostStream/Views/LauncherView.swift:5-360`
- Modify: `GhostStream/Views/SettingsView.swift:3-220`
- Test: `regression_unified_sources_player.py`

**Interfaces:**
- Consumes: existing `LauncherView(onClose:)`, `AddSourceView`, `SavedSourcesView`, `SourceStore`, `LibraryViewModel`, `EPGService`.
- Produces: Sources screen suitable as an iPhone tab and iPad primary destination; Settings reachable from gear, not primary iPhone tab.

- [ ] **Step 1: Write the failing Sources/Settings regression**

Create `regression_unified_sources_player.py` initially with:

```python
from pathlib import Path
root = Path(__file__).parent
launcher = (root / "GhostStream/Views/LauncherView.swift").read_text()
settings = (root / "GhostStream/Views/SettingsView.swift").read_text()

assert 'Image("GhostHomeHero")' in launcher
assert "Theme.accentBright" in launcher
assert "CONTENT & RIGHTS" in settings
assert "GhostStream uses the black and purple" in settings
```

- [ ] **Step 2: Run and verify RED**

Run: `python3 regression_unified_sources_player.py`

Expected: FAIL at least on the hero/accent-bright requirements.

- [ ] **Step 3: Restyle Launcher/Sources without changing source logic**

Replace the old cyan launcher background/art with `GhostHomeHero` plus the unified black/purple gradient. Keep the existing source actions and logic exactly:

```text
Playlist URL
M3U File
Provider Login
Single Stream
Saved Sources
```

Do not change source validation, `library.load(source:)`, `store.add`, `store.setActive`, or security-scoped file import behavior.

- [ ] **Step 4: Optimize Source layout per device**

Use the existing geometry checks to keep two compact columns on phone and a centered/wider 2-column touch layout on iPad. Keep `onClose` behavior for modal/change-source usage; when used as a primary tab/destination with `onClose == nil`, do not show a fake Back button.

- [ ] **Step 5: Align Settings cards and copy with the unified purple theme**

Keep all existing Settings actions and content-rights disclosure. Ensure the App Style sheet describes the black/purple theme and the device-appropriate navigation model.

- [ ] **Step 6: Run regression and parse**

Run:

```bash
python3 regression_unified_sources_player.py
swiftc -parse GhostStream/Views/LauncherView.swift
swiftc -parse GhostStream/Views/SettingsView.swift
```

Expected: PASS / exit 0.

- [ ] **Step 7: Commit**

```bash
git add GhostStream/Views/LauncherView.swift GhostStream/Views/SettingsView.swift regression_unified_sources_player.py
git commit -m "feat: unify Sources and Settings styling"
```

---

### Task 6: Align iPhone/iPad Player Chrome with TV Behavior Without Changing Engines

**Files:**
- Modify: `GhostStream/Views/PlayerView.swift:42-845`
- Extend test: `regression_unified_sources_player.py`
- Existing tests: `regression_vod_player_features.py`, `regression_vod_player_upgrade.py`, `regression_series_episode_transition.py`, `regression_ios_live_mockup_player.py`

**Interfaces:**
- Consumes: existing `NativePlayerSurface`, `EmbeddedCompatibilityPlayer`, `SeriesPlaybackContext`, `VODResumeStore`.
- Produces: title-free video surface when controls are hidden; controls auto-hide; Back remains available when controls are shown; existing VOD audio/subtitle/seek/speed/fit/fill/episode controls remain.

- [ ] **Step 1: Extend the regression for title-free auto-hiding player chrome**

Append to `regression_unified_sources_player.py`:

```python
player = (root / "GhostStream/Views/PlayerView.swift").read_text()
assert "scheduleControlsHide()" in player
assert "controlsHideWorkItem?.cancel()" in player
assert "episodeSwitchInProgress" in player
assert "DispatchQueue.main.asyncAfter(deadline: .now() + 0.20)" in player
assert 'Text(title)' not in player[player.index("private var liveMockupOverlay"):player.index("private var vodControlsOverlay")]
assert "loadMediaSelectionGroup(for:" in player
```

- [ ] **Step 2: Run and verify RED**

Run: `python3 regression_unified_sources_player.py`

Expected: FAIL because the current Live overlay permanently renders `Text(title)` when controls are visible.

- [ ] **Step 3: Remove channel/movie/episode title clutter from playback chrome**

Remove the persistent top/bottom `Text(title)` / `Text(effectiveTitle)` labels that duplicate the currently playing item name. Keep only contextual programme/episode information when the user explicitly opens the corresponding info/EPG panel.

- [ ] **Step 4: Preserve auto-hide and restore-on-tap behavior**

Do not change the existing `controlsVisible`, `controlsHideWorkItem`, `PlayerTapCatcher`, `scheduleControlsHide()`, or `showControlsFromTap()` architecture except for styling. All player buttons use the unified purple accent.

- [ ] **Step 5: Preserve VOD and Series behavior exactly**

Verify the implementation still contains:

```swift
loadMediaSelectionGroup(for:)
```

for AVPlayer real tracks, the MobileVLCKit track APIs, per-content resume keys, `playAdjacentEpisode(offset:)`, two-phase `episodeSwitchInProgress` teardown, and auto-play-next.

- [ ] **Step 6: Run player regressions and parse**

Run:

```bash
python3 regression_unified_sources_player.py
python3 regression_vod_player_features.py
python3 regression_vod_player_upgrade.py
python3 regression_series_episode_transition.py
python3 regression_ios_live_mockup_player.py
swiftc -parse GhostStream/Views/PlayerView.swift
```

Expected: all PASS / exit 0.

- [ ] **Step 7: Commit**

```bash
git add GhostStream/Views/PlayerView.swift regression_unified_sources_player.py
git commit -m "feat: align iOS playback chrome with tvOS"
```

---

### Task 7: Protect Apple TV Behavior and Cross-Device Boundaries

**Files:**
- Do not intentionally modify: `GhostStreamTV/TVRootView.swift`
- Test: existing tvOS regression scripts
- Test: add tvOS checksum/reference assertion to `regression_unified_theme_home.py`

**Interfaces:**
- Consumes: current tvOS UI/behavior as the reference design.
- Produces: evidence that iOS unification did not regress tvOS source loading, Live preview, menus, episode transition, or Home navigation.

- [ ] **Step 1: Add an explicit tvOS behavior-preservation check**

Append to `regression_unified_theme_home.py`:

```python
tv = (root / "GhostStreamTV/TVRootView.swift").read_text()
for token in [
    "TVGhostHomeHero",
    "TVLivePreviewPanel",
    "previewWorkItem?.cancel()",
    "episodeSwitchInProgress",
    "GhostHomeHero",
]:
    assert token in tv, f"tvOS reference behavior missing: {token}"
```

- [ ] **Step 2: Run the tvOS preservation gate**

Run:

```bash
python3 regression_unified_theme_home.py
python3 regression_tvos_home_dashboard.py
python3 regression_tvos_live_nav_and_playback.py
python3 regression_tvos_player_source_stability.py
python3 regression_tvos_menu_integrity.py
python3 regression_tvos_vod_options.py
python3 regression_series_episode_transition.py
```

Expected: all PASS. If an older regression asserts a symbol intentionally superseded before this project version, confirm `TVRootView.swift` itself is unchanged in this implementation and update only that stale regression expectation; do not modify tvOS UI to satisfy obsolete test text.

- [ ] **Step 3: Parse tvOS Swift source**

Run: `swiftc -parse GhostStreamTV/TVRootView.swift`

Expected: exit 0.

- [ ] **Step 4: Commit test-only guard changes**

```bash
git add regression_unified_theme_home.py
git commit -m "test: guard tvOS behavior during iOS unification"
```

---

### Task 8: Full Regression, Project Integrity, and Test Package

**Files:**
- Verify: all modified Swift/assets/tests above
- Verify: `GhostStream.xcodeproj/project.pbxproj`
- Verify: `Frameworks/MobileVLCKit.xcframework`
- Verify: `Frameworks/TVVLCKit.xcframework`
- Output: `/mnt/data/GhostStream-Xcode-Unified-iPhone-iPad-TV-UI-Test.zip`

**Interfaces:**
- Produces: one universal iOS + tvOS Xcode project ZIP ready for simulator/device runtime testing.

- [ ] **Step 1: Run every new unified regression**

```bash
python3 regression_unified_theme_home.py
python3 regression_ios_live_preview_unified.py
python3 regression_unified_media_layout.py
python3 regression_unified_sources_player.py
```

Expected: all PASS.

- [ ] **Step 2: Run the existing iOS/VOD/source regressions**

```bash
python3 regression_ios_controls_settings_icon.py
python3 regression_ios_favorites_change_source.py
python3 regression_ios_landscape_source_switch.py
python3 regression_ios_live_mockup_player.py
python3 regression_ios_live_fit_title.py
python3 regression_source_fetch.py
python3 regression_vod_player_features.py
python3 regression_vod_player_upgrade.py
python3 regression_series_episode_transition.py
```

Expected: all PASS. Any stale source-string regression must be updated only when behavior is intentionally preserved under a renamed/restructured view; do not remove functionality to satisfy a stale assertion.

- [ ] **Step 3: Run tvOS, Xcode, and bundled-framework regressions**

```bash
python3 regression_tvos_home_dashboard.py
python3 regression_tvos_live_nav_and_playback.py
python3 regression_tvos_player_source_stability.py
python3 regression_tvos_menu_integrity.py
python3 regression_tvos_vod_options.py
python3 regression_xcode265.py
python3 regression_bundled_vlckit.py
python3 regression_vlckit_runtime_bundle.py
```

Expected: all PASS.

- [ ] **Step 4: Parse every Swift source file**

Run:

```bash
find GhostStream GhostStreamTV -name '*.swift' -print0 | while IFS= read -r -d '' file; do
    echo "Parsing $file"
    swiftc -parse "$file" || exit 1
done
```

Expected: exit 0 with every Swift file parsed.

- [ ] **Step 5: Confirm project/device-family integrity**

Run:

```bash
grep -n 'TARGETED_DEVICE_FAMILY = "1,2"' GhostStream.xcodeproj/project.pbxproj
grep -n 'PRODUCT_BUNDLE_IDENTIFIER = com.ghoststream.tv' GhostStreamTV.xcodeproj/project.pbxproj
```

Expected: iOS remains universal iPhone/iPad; tvOS bundle identifier remains unchanged.

- [ ] **Step 6: Package the test project**

From the parent directory of `GhostStream-APK-Theme`:

```bash
zip -qry /mnt/data/GhostStream-Xcode-Unified-iPhone-iPad-TV-UI-Test.zip GhostStream-APK-Theme
unzip -t /mnt/data/GhostStream-Xcode-Unified-iPhone-iPad-TV-UI-Test.zip | tail -n 3
```

Expected: ZIP integrity reports no errors.

- [ ] **Step 7: Runtime verification checklist for the Mac**

In Xcode 26.x, manually verify:

```text
iPhone simulator/device:
- Home bottom tabs are Home / Live / Movies / Series / Sources.
- Home gear opens Settings.
- Live channel tap opens preview/details; scrolling alone does not auto-preview.
- Play opens full-screen Live player.
- Movies and Series open/play correctly.

iPad simulator/device (portrait + landscape):
- TV-style top nav is visible; no left sidebar.
- Live selection starts muted preview after ~0.75s.
- Changing selection cancels stale preview.
- Movies/Series use wider grids.
- Sources and Settings remain touch-friendly.

Apple TV simulator/device:
- Existing Home/top nav remains unchanged.
- Live focus preview still works.
- Sources dismiss correctly after load.
- Next/Previous Episode and playback options still work.
```

- [ ] **Step 8: Commit final verification metadata**

```bash
git status --short
git log --oneline -8
```

Do not claim Xcode compilation/runtime success unless the relevant `xcodebuild` or Xcode/device run was actually performed on macOS. The container verification proves source parsing/regression/package integrity only.

---

## Self-Review Results

- Spec coverage: all approved Navigation, Home, Live Preview, Movies/VOD, Series, Sources, Settings, Shared Design, Performance, Accessibility, and Regression requirements map to Tasks 1-8.
- Placeholder scan: no unresolved placeholders or undefined neighboring interfaces remain.
- Type consistency: `GhostPrimarySection`, `GhostLivePreviewMode`, `GhostLivePreviewPanel`, and existing `SeriesPlaybackContext` names are consistent across tasks.
- Scope: this remains one cohesive UI-unification implementation over existing targets; provider APIs, player engines, account/cloud features, and tvOS redesign remain explicitly out of scope.
