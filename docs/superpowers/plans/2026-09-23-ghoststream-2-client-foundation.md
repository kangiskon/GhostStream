# GhostStream 2.0 Apple Client Foundation, Account, Dashboard & Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the legacy source-first iPhone/iPad shell with the approved GhostStream 2.0 account-aware Dashboard and client foundation while preserving valid existing local sources through migration.

**Architecture:** Add focused Swift services for API transport, session storage, account state, device identity, sync, deletion, and migration. The new root chooses between authentication and the new dashboard shell. Existing media/library/player code stays callable during migration but no longer defines the top-level information architecture.

**Tech Stack:** Swift 5, SwiftUI, AuthenticationServices, CryptoKit, Security/Keychain, URLSession, existing AVPlayer/MobileVLCKit integration, iOS/iPadOS 16+.

**Spec:** `docs/superpowers/specs/2026-09-23-ghoststream-2-architecture-design.md`

## Global Constraints

- iOS deployment target remains 16.0 unless a specific new API requires availability guards.
- Primary navigation becomes Home, Library, Devices, Intelligence, More.
- Provider credentials remain in Keychain and are never included in cloud sync payloads.
- Existing local sources migrate without forced data loss.
- Account deletion must erase all local GhostStream data after confirmed server deletion/revocation.
- Visual system follows the approved dark navy/black + purple/indigo concept.

## Review Focus

- Upgrade with pre-existing saved Provider Login source: source remains usable after migration and password is not uploaded.
- Expired access token while app resumes: refresh occurs once and concurrent requests do not trigger a refresh storm.
- Server returns `410 account_deleted`: client wipes before showing authenticated UI.
- Sign in with Apple returns no email on later login: account still signs in using verified Apple identity token.
- App launched offline with a valid local source: local playback remains available where possible without pretending cloud sync succeeded.

---

### Task 1: Shared API models and transport

**Files:**
- Create: `GhostStream/Account/APIModels.swift`
- Create: `GhostStream/Account/GhostStreamAPIClient.swift`
- Create: `GhostStream/Account/APIError.swift`
- Create: `regression_ghoststream2_api_models.py`
- Modify: `GhostStream.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces:
  - `protocol GhostStreamAPITransport`
  - `actor GhostStreamAPIClient`
  - Codable models `TokenPairDTO`, `AccountDTO`, `DeviceDTO`, `SyncEnvelopeDTO`, `APIErrorEnvelope`.

- [ ] **Step 1: Add regression test**

Assert new Swift files exist, do not define fields named `providerPassword`, `authorizationHeader`, or `playlistBody` in sync DTOs, and project includes them in iOS target.

- [ ] **Step 2: Run and verify failure**

Run: `python3 regression_ghoststream2_api_models.py`.

- [ ] **Step 3: Implement API client**

Use `URLSession.data(for:)`; encode JSON with ISO-8601 dates. Map HTTP 410 + `account_deleted` to `APIError.accountDeleted`. API base defaults to `https://ghoststreams.ink/api/v1` and is injectable for tests.

- [ ] **Step 4: Build**

Run:
`xcodebuild -project GhostStream.xcodeproj -scheme GhostStream -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`

- [ ] **Step 5: Commit**

Commit: `feat(ios): add GhostStream API client`.

### Task 2: Secure account session store and device identity

**Files:**
- Create: `GhostStream/Account/SessionVault.swift`
- Create: `GhostStream/Devices/DeviceIdentityService.swift`
- Create: `GhostStream/Devices/DeviceModels.swift`
- Create: `regression_ghoststream2_identity.py`
- Modify: `GhostStream/GhostStreamApp.swift`

**Interfaces:**
- `SessionVault.saveRefreshToken(_:accountID:)`
- `SessionVault.readRefreshToken() -> String?`
- `SessionVault.clear()`
- `DeviceIdentityService.loadOrCreate() throws -> DeviceIdentity`
- `DeviceIdentity` contains stable UUID and Curve25519 public key; private key stays in Keychain.

- [ ] **Step 1: Add regression assertions**

Ensure private-key data is only passed to Security/Keychain APIs and never encoded in API DTOs/UserDefaults.

- [ ] **Step 2: Implement Keychain-backed session vault**

Use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Access tokens stay memory-only; refresh token stays Keychain-only.

- [ ] **Step 3: Implement CryptoKit identity**

Generate `Curve25519.KeyAgreement.PrivateKey()`; store raw private key in Keychain; register base64 public key only.

- [ ] **Step 4: Build and run regression**

Run xcodebuild command above and `python3 regression_ghoststream2_identity.py`.

- [ ] **Step 5: Commit**

Commit: `feat(ios): add secure account and device identity`.

### Task 3: AccountStore, email/password, and Sign in with Apple

**Files:**
- Create: `GhostStream/Account/AccountStore.swift`
- Create: `GhostStream/Account/AuthView.swift`
- Create: `GhostStream/Account/AppleSignInCoordinator.swift`
- Create: `regression_ghoststream2_auth_ui.py`
- Modify: `GhostStream/GhostStreamApp.swift`

**Interfaces:**
- `@MainActor final class AccountStore: ObservableObject`
- Published state: `status`, `account`, `devices`, `syncState`.
- Methods:
  - `register(email:password:)`
  - `signIn(email:password:)`
  - `signInWithApple(identityToken:authorizationCode:)`
  - `signOut()`
  - `restoreSession()`.

- [ ] **Step 1: Write UI regression expectations**

Auth screen must contain email, password, Sign In, Create Account, Forgot Password, and native Sign in with Apple button.

- [ ] **Step 2: Implement AccountStore token refresh serialization**

Use an actor or one in-flight refresh `Task` so multiple 401s await the same refresh.

- [ ] **Step 3: Implement native Apple flow**

Use `SignInWithAppleButton` and `ASAuthorizationAppleIDCredential.identityToken`. Never synthesize identity from email.

- [ ] **Step 4: Build and regression test**

Run xcodebuild + `python3 regression_ghoststream2_auth_ui.py`.

- [ ] **Step 5: Commit**

Commit: `feat(ios): add GhostStream account authentication`.

### Task 4: New GhostStream 2.0 app shell and dashboard

**Files:**
- Create: `GhostStream/Dashboard/GhostDashboardView.swift`
- Create: `GhostStream/Dashboard/DashboardModels.swift`
- Create: `GhostStream/Shell/GhostStreamShellView.swift`
- Create: `GhostStream/Shell/GhostStreamNavigation.swift`
- Create: `GhostStream/Library/GhostLibraryHubView.swift`
- Create: `GhostStream/More/GhostMoreView.swift`
- Modify: `GhostStream/Views/RootTabView.swift`
- Create: `regression_ghoststream2_navigation.py`

**Interfaces:**
- Primary enum: `GhostStreamSection { home, library, devices, intelligence, more }`.
- Existing `LiveView`, `MoviesView`, `SeriesView`, `LauncherView` are reached from Library/Sources, not top-level tabs.

- [ ] **Step 1: Write navigation regression**

Fail if top-level tab labels are exactly the old `Home/Live/Movies/Series/Sources` set. Require `Devices` and `Intelligence`.

- [ ] **Step 2: Implement shell**

Phone: bottom tabs Home, Library, Devices, Intelligence, More.  
iPad: adaptive top/side control is allowed, but video playback must remain full-screen-capable.

- [ ] **Step 3: Implement dashboard cards matching concept**

Required cards/rails:
- account + device status
- Continue Watching
- Source Health
- quick Library actions
- paired devices
- recent activity.

Use real app state; no fake network/content data in production paths.

- [ ] **Step 4: Build and regress**

Run xcodebuild and regression script.

- [ ] **Step 5: Commit**

Commit: `feat(ios): replace legacy shell with GhostStream dashboard`.

### Task 5: Legacy source migration and sanitized source metadata

**Files:**
- Create: `GhostStream/Sources/SourceMigrationCoordinator.swift`
- Create: `GhostStream/Sources/CloudSourceProfile.swift`
- Modify: `GhostStream/Services/SourceStore.swift`
- Create: `regression_ghoststream2_source_migration.py`

**Interfaces:**
- `migrateIfNeeded() -> MigrationResult`
- `CloudSourceProfile.init(source:) -> CloudSourceProfile` must omit secrets/raw URL where prohibited.

- [ ] **Step 1: Add regression fixtures**

Represent an old `Source` containing server URL, username, password. Assert migration preserves local source and Keychain secret while cloud DTO excludes password.

- [ ] **Step 2: Add migration version**

Persist `ghoststream.v2.migration.completed`. Migration is idempotent.

- [ ] **Step 3: Update SourceStore**

Keep existing source IDs stable. Expose explicit `wipeAllLocalData()` later used by deletion coordinator.

- [ ] **Step 4: Build and regress**

Run xcodebuild + regression.

- [ ] **Step 5: Commit**

Commit: `feat(ios): migrate legacy sources safely`.

### Task 6: Sync engine, Continue Watching foundation, and account-deleted handling

**Files:**
- Create: `GhostStream/Sync/SyncEngine.swift`
- Create: `GhostStream/Activity/PlaybackProgressStore.swift`
- Create: `GhostStream/Activity/ActivityStore.swift`
- Create: `GhostStream/Account/GlobalDeletionCoordinator.swift`
- Create: `regression_ghoststream2_sync_deletion.py`
- Modify: `GhostStream/GhostStreamApp.swift`

**Interfaces:**
- `SyncEngine.start(accountStore:)`
- `SyncEngine.pushPending()`
- `SyncEngine.pull()`
- `PlaybackProgressStore.record(...)`
- `GlobalDeletionCoordinator.wipeAndSignOut(reason:)`.

- [ ] **Step 1: Write static regression around deletion wipe coverage**

Require calls that clear SourceStore, provider Keychain secrets, favorites, playback progress, caches, EPG, device pairing state, session vault, and sync cursor.

- [ ] **Step 2: Implement sync queue**

Persist sanitized pending operations locally. Deletion/revocation state has precedence over all queued writes.

- [ ] **Step 3: Implement 410 handling**

Any API path receiving `APIError.accountDeleted` invokes global wipe before authenticated UI is allowed again.

- [ ] **Step 4: Build and regress**

Run xcodebuild + regression.

- [ ] **Step 5: Commit**

Commit: `feat(ios): add sync and global wipe foundation`.
