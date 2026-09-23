# GhostStream 2.0 Source Intelligence, Continuity, Visual Rebuild & App Review Completion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete GhostStream 2.0 with the approved Source Intelligence Center, cross-device playback continuity, redesigned iPhone/iPad/Apple TV presentation, original asset reset, website deletion integration, and App Store review verification.

**Architecture:** Diagnostics run on-device against user-supplied sources and emit a sanitized report model suitable for sync. Playback progress feeds a shared activity model. New feature-specific SwiftUI views replace template-like surfaces, while legacy player engines are retained behind GhostStream-owned interfaces. Final tasks remove obsolete assets, connect deletion web flow to the canonical backend, and verify all App Review scenarios.

**Tech Stack:** SwiftUI, AVFoundation/AVPlayer, existing MobileVLCKit/TVVLCKit compatibility path, Network/Foundation timing APIs, CryptoKit/Security, FastAPI, HTML/CSS/JS deletion portal, Python regression scripts, Xcode builds.

**Spec:** `docs/superpowers/specs/2026-09-23-ghoststream-2-architecture-design.md`

## Global Constraints

- Source diagnostics must never upload raw URLs, passwords, playlist bodies, authorization headers, or provider responses containing secrets.
- Health scores are explainable and each score exposes contributing reasons.
- Continue Watching syncs movie/episode progress across trusted signed-in devices.
- Live/Movies/Series remain library capabilities but are not the top-level product identity.
- New design must follow the approved dark purple/black command-center concept across iPhone, iPad, and Apple TV.
- Obsolete/template-like legacy assets are removed or replaced before release.
- Website and in-app account deletion call the same backend deletion path.

## Review Focus

- Diagnostic probe of malformed or unreachable URL must return a safe categorized failure and never crash.
- Provider 401/403 must be described as authentication failure without logging credentials.
- Playback progress from two devices must converge to the newest valid state.
- Global account deletion while a movie is playing must stop playback, clear local secrets, and return to signed-out screen.
- App Review demo with only developer-owned sample media must exercise pairing, diagnostics, library, playback, and deletion without third-party content.

---

### Task 1: Source diagnostic domain model and health scoring

**Files:**
- Create: `GhostStream/Intelligence/DiagnosticModels.swift`
- Create: `GhostStream/Intelligence/HealthScoreCalculator.swift`
- Create: `regression_ghoststream2_health_score.swift`
- Modify: `GhostStream.xcodeproj/project.pbxproj`

**Interfaces:**
- `DiagnosticSnapshot`
- `DiagnosticIssue`
- `DiagnosticRecommendation`
- `HealthScoreCalculator.score(_:) -> HealthScoreResult`.

- [ ] **Step 1: Write failing Swift regression**

Cases:
- stable stream => high score and “stable” reason
- repeated buffering lowers score
- unsupported codec lowers compatibility component
- total connection failure => zero/critical
- score always clamps 0...100.

- [ ] **Step 2: Implement pure scoring logic**

Inputs are normalized metrics only. Return numeric score plus ordered reason list so UI never displays an unexplained number.

- [ ] **Step 3: Run regression**

Compile/run the standalone regression against source files or add XCTest equivalent.

- [ ] **Step 4: Build and commit**

Commit: `feat(intelligence): add explainable source health scoring`.

### Task 2: On-device SourceDiagnosticsService

**Files:**
- Create: `GhostStream/Intelligence/SourceDiagnosticsService.swift`
- Create: `GhostStream/Intelligence/MediaProbe.swift`
- Create: `GhostStream/Intelligence/DiagnosticSanitizer.swift`
- Create: `regression_ghoststream2_diagnostics.py`

**Interfaces:**
- `diagnose(source:) async -> DiagnosticSnapshot`
- `sanitize(_:) -> DiagnosticSnapshotDTO`.

- [ ] **Step 1: Regression for forbidden sync content**

Scan sanitizer output declarations and fixture serialization; fail if raw URL, username, password, auth header, or playlist body appears.

- [ ] **Step 2: Implement staged diagnostics**

Measure:
- source/API reachability
- response time
- stream-start latency
- media resolution where available
- video/audio codec
- container
- bitrate estimate
- buffering events observed during playback session
- normalized failure category.

Use AVAsset/AVPlayer metadata first; use existing compatibility player metadata only where needed.

- [ ] **Step 3: Implement categorized errors**

Enum includes:
`networkUnavailable`, `dnsFailure`, `timeout`, `authenticationFailed`, `notFound`, `malformedSource`, `unsupportedMedia`, `providerUnavailable`, `unknown`.

- [ ] **Step 4: Build/regress and commit**

Commit: `feat(intelligence): add on-device source diagnostics`.

### Task 3: Source Intelligence Center UI and history sync

**Files:**
- Create: `GhostStream/Intelligence/SourceIntelligenceView.swift`
- Create: `GhostStream/Intelligence/SourceHealthDetailView.swift`
- Create: `GhostStream/Intelligence/DiagnosticHistoryView.swift`
- Modify: `GhostStream/Sync/SyncEngine.swift`
- Create: `regression_ghoststream2_intelligence_ui.py`

**Interfaces:**
- Tabs/panels: Overview, Diagnostics, Health, History, Recommendations.

- [ ] **Step 1: UI regression**

Require health score, online/offline, last checked, response time, latency, bitrate, resolution, codec, container, chart/history, status explanation, recommendations.

- [ ] **Step 2: Implement dashboard matching concept**

Use large score ring, metric grid, history graph, status card, and diagnostic action. iPad can show split summary/detail; iPhone stacks cards.

- [ ] **Step 3: Sync sanitized history**

Only `DiagnosticSnapshotDTO` enters SyncEngine.

- [ ] **Step 4: Build/regress and commit**

Commit: `feat(intelligence): add Source Intelligence Center`.

### Task 4: Playback progress, Continue Watching, and cross-device continuity

**Files:**
- Modify: `GhostStream/Views/PlayerView.swift`
- Modify: `GhostStream/Activity/PlaybackProgressStore.swift`
- Create: `GhostStream/Activity/ContinueWatchingView.swift`
- Modify: `GhostStream/Dashboard/GhostDashboardView.swift`
- Modify: `GhostStreamTV/TVRootView.swift`
- Create: `regression_ghoststream2_continuity.py`

**Interfaces:**
- Progress key = account + source profile + content kind + content id.
- Save every bounded interval plus pause/background/exit.
- Resume from newest valid synced position.

- [ ] **Step 1: Regression expectations**

Require player calls to progress store, dashboard Continue Watching rail, tvOS Continue Watching, and conflict timestamp handling.

- [ ] **Step 2: Integrate player progress**

For VOD/episodes, publish progress no more often than every 10 seconds plus lifecycle events. Do not sync live-channel scrub time as VOD progress.

- [ ] **Step 3: Resume logic**

If completion >= 95%, mark completed and omit from Continue Watching unless user explicitly restarts.

- [ ] **Step 4: Build iOS/tvOS and commit**

Commit: `feat(playback): add cross-device continuity`.

### Task 5: Complete Devices, Sources, Library, Activity, and More screens to approved visual design

**Files:**
- Modify: `GhostStream/Devices/DevicesView.swift`
- Modify: `GhostStream/Views/LauncherView.swift`
- Modify: `GhostStream/Library/GhostLibraryHubView.swift`
- Create: `GhostStream/Activity/ActivityView.swift`
- Modify: `GhostStream/More/GhostMoreView.swift`
- Create: `GhostStream/Design/GhostDesignSystem.swift`
- Create: `regression_ghoststream2_visual_shell.py`

**Interfaces:**
- Shared design tokens: background, surface, elevated surface, accent, accentBright, border, success, warning, destructive, corner radii, spacing.

- [ ] **Step 1: Centralize visual tokens**

Move new GhostStream 2.0 design values out of oversized root views.

- [ ] **Step 2: Rebuild Sources cards**

Each card shows connection state, health, last refresh, available content, and device credential availability; actions Connect, Disconnect, Edit, Diagnose, Send, Delete.

- [ ] **Step 3: Build Activity + Library hubs**

Library contains Live TV/Movies/Series/Favorites/Search/Categories. Activity contains Continue Watching, recent playback, clear-item/clear-all.

- [ ] **Step 4: Fix touch targets**

Interactive controls minimum 44x44 points; phone settings control target >= 52x52 where space permits.

- [ ] **Step 5: Build/regress and commit**

Commit: `feat(ui): complete GhostStream command center surfaces`.

### Task 6: Apple TV command-center redesign

**Files:**
- Create: `GhostStreamTV/Dashboard/TVDashboardView.swift`
- Create: `GhostStreamTV/Devices/TVDevicesView.swift`
- Create: `GhostStreamTV/Intelligence/TVSourceHealthView.swift`
- Create: `GhostStreamTV/Design/TVGhostDesignSystem.swift`
- Modify: `GhostStreamTV/TVRootView.swift`
- Create: `regression_ghoststream2_tvos_dashboard.py`

**Interfaces:**
- TV top-level areas: Home, Library, Devices, Source Health, Settings.
- Home contains Continue Watching and quick Live/Movies/Series entry.

- [ ] **Step 1: Regression rejects legacy-only home**

Fail if TV root still makes active source setup + Live/Movies/Series shell the only primary experience.

- [ ] **Step 2: Build focus-safe new dashboard**

Use native focus, large cards, source health badge, device state, Continue Watching rails. Preserve existing player navigation and Siri Remote behavior.

- [ ] **Step 3: Build tvOS**

Run tvOS xcodebuild.

- [ ] **Step 4: Commit**

Commit: `feat(tvos): add GhostStream command center`.

### Task 7: Original asset reset and app icon package

**Files:**
- Modify/Create: `GhostStream/Assets.xcassets/AppIcon.appiconset/*`
- Create: `GhostStream/Assets.xcassets/GhostStream2Wordmark.imageset/*`
- Create: `GhostStream/Assets.xcassets/GhostStream2Hero.imageset/*`
- Modify/Create corresponding tvOS assets in `GhostStreamTV/Assets.xcassets`
- Delete obsolete legacy sets after confirming no references: `APKBrandLogo.imageset`, `APKPattern.imageset`, and other superseded theme duplicates.
- Create: `regression_ghoststream2_assets.py`

**Interfaces:**
- Only new product-owned GhostStream 2.0 assets referenced by new shell.

- [ ] **Step 1: Inventory references**

Search Swift and asset catalogs for every legacy asset name. Do not delete any still required by a not-yet-migrated screen.

- [ ] **Step 2: Generate/import original assets matching approved concept**

App icon and wordmark use the new purple geometric GhostStream identity; hero uses original abstract/cinematic art with no third-party copyrighted artwork.

- [ ] **Step 3: Update references and delete obsolete sets**

Regression fails if `APKBrandLogo` or `APKPattern` remains referenced in production Swift.

- [ ] **Step 4: Validate asset catalogs**

Run both xcodebuild commands and inspect warnings for missing images.

- [ ] **Step 5: Commit**

Commit: `feat(brand): replace legacy assets with GhostStream 2.0 originals`.

### Task 8: In-app account settings and global deletion UX

**Files:**
- Create: `GhostStream/Account/AccountSettingsView.swift`
- Create: `GhostStream/Account/DeleteAccountView.swift`
- Modify: `GhostStream/Account/GlobalDeletionCoordinator.swift`
- Create: `regression_ghoststream2_delete_account.py`

**Interfaces:**
- Delete flow: warning -> re-authentication where required -> API delete -> local wipe -> signed-out welcome.
- Include direct link to web deletion page as alternate access path.

- [ ] **Step 1: Regression checks wording and coverage**

Require warning to mention cloud account, saved sources, credentials, favorites, history, progress, paired devices, diagnostics, all signed-in devices.

- [ ] **Step 2: Implement destructive confirmation**

Do not permit accidental one-tap deletion from settings list.

- [ ] **Step 3: Stop active playback before wipe**

Coordinate player dismissal then wipe SourceStore, Keychain, caches, EPG, activity, sync, pairings, account tokens.

- [ ] **Step 4: Build/regress and commit**

Commit: `feat(account): add complete global deletion flow`.

### Task 9: Website deletion portal integration

**Files:**
- Create: `backend/web/delete-account/index.html`
- Create: `backend/web/delete-account/app.js`
- Create: `backend/web/delete-account/styles.css`
- Create: `backend/tests/test_deletion_web_contract.py`
- Modify: `backend/DEPLOY.md`

**Interfaces:**
- Website authenticates user and calls the same `POST /api/v1/account/delete` endpoint.

- [ ] **Step 1: Contract test**

Assert website JS references canonical API endpoint and never claims that deletion is only an email/request form.

- [ ] **Step 2: Build accessible deletion page**

Show exactly what will be deleted; require authenticated confirmation; display completion/failure state.

- [ ] **Step 3: Verify against local backend**

Use disposable account and confirm server data deletion + old token returns 410.

- [ ] **Step 4: Commit**

Commit: `feat(web): connect account deletion portal`.

### Task 10: Privacy manifests, review notes, and end-to-end release gate

**Files:**
- Modify: `GhostStream/PrivacyInfo.xcprivacy`
- Modify: `GhostStreamTV/PrivacyInfo.xcprivacy`
- Modify: `APP-STORE-COMPLIANCE-CHANGES.txt`
- Modify: `APP-STORE-SUBMISSION-NOTES.txt`
- Create: `GHOSTSTREAM-2-REVIEW-WALKTHROUGH.md`
- Create: `regression_ghoststream2_release.py`

**Interfaces:**
- Final review walkthrough includes account, pairing, diagnostics, cross-device progress, playback, and deletion.

- [ ] **Step 1: Audit actual data flow**

Update privacy manifests/disclosures based on implemented SDK/API behavior, not planned behavior.

- [ ] **Step 2: Run all repository regressions**

Run:
```bash
python3 regression_ghoststream2_api_models.py
python3 regression_ghoststream2_identity.py
python3 regression_ghoststream2_auth_ui.py
python3 regression_ghoststream2_navigation.py
python3 regression_ghoststream2_source_migration.py
python3 regression_ghoststream2_sync_deletion.py
python3 regression_ghoststream2_pairing_ui.py
python3 regression_ghoststream2_tvos_pairing.py
python3 regression_ghoststream2_credential_crypto.py
python3 regression_ghoststream2_device_management.py
python3 regression_ghoststream2_diagnostics.py
python3 regression_ghoststream2_intelligence_ui.py
python3 regression_ghoststream2_continuity.py
python3 regression_ghoststream2_visual_shell.py
python3 regression_ghoststream2_tvos_dashboard.py
python3 regression_ghoststream2_assets.py
python3 regression_ghoststream2_delete_account.py
python3 regression_ghoststream2_release.py
```

- [ ] **Step 3: Run full backend suite**

Run: `cd backend && pytest -q`.

- [ ] **Step 4: Build iOS and tvOS**

Run both simulator xcodebuild commands with code signing disabled. Then build/run on physical iPhone/iPad/Apple TV in Xcode.

- [ ] **Step 5: Execute end-to-end App Review scenario**

1. Create/sign into review account.
2. Pair Apple TV by QR.
3. Add developer-owned demo source.
4. Transfer credential/source securely.
5. Run diagnostics and show sanitized history.
6. Play demo movie/episode on TV.
7. Resume on iPhone/iPad.
8. Show Devices + Source Intelligence.
9. Show in-app delete-account entry.
10. Perform a separate disposable-account deletion from website and confirm all devices wipe/revoke.

- [ ] **Step 6: Commit**

Commit: `chore(release): prepare GhostStream 2.0 App Store review`.
