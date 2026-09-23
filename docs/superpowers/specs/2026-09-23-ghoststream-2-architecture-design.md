# GhostStream 2.0 — Product and Architecture Design

Date: 2026-09-23  
Status: Approved design, awaiting implementation-plan approval  
Repository: `kangiskon/GhostStream`

## 1. Purpose

GhostStream 2.0 is a substantial redesign of the existing app in response to App Store Review feedback under Guideline 4.3(a). The product must no longer present primarily as a conventional IPTV/M3U player with a familiar Live / Movies / Series / Sources shell.

The new product is a **Personal Streaming Command Center + Cross-Device Media Hub** for user-provided, authorized media sources.

Playback remains an important capability, but the product identity is centered on:

- GhostStream accounts and trusted devices
- secure cross-device pairing and continuity
- source intelligence and diagnostics
- privacy-preserving source credential handling
- synchronized favorites, history, and progress
- device-aware compatibility guidance
- full in-app and web account deletion with global device wipe

The experience must match the approved dark purple/black visual direction shown in the GhostStream 2.0 concept board, including the layout hierarchy, brand feel, feature emphasis, and polished multi-device presentation.

## 2. App Store differentiation goal

The redesign must address both areas Apple identified:

### 2.1 Concept differentiation

GhostStream must be demonstrably more than a generic IPTV player.

Primary product flows are:

1. Sign in or create a GhostStream account.
2. Register and manage trusted devices.
3. Pair Apple TV / iPad / iPhone with QR code or 6-digit code.
4. Add authorized user-provided sources.
5. Diagnose source health and playback compatibility.
6. Securely transfer source credentials directly between trusted devices.
7. Watch content and continue across devices.
8. Review synced activity, favorites, progress, and diagnostics.
9. Delete the account and all GhostStream data from every signed-in device.

### 2.2 Binary/source/assets differentiation

The main application shell must be substantially rebuilt rather than cosmetically modified.

Requirements:

- Replace the current Live / Movies / Series / Sources-first navigation shell.
- Build new GhostStream-owned services for account state, sync, pairing, diagnostics, deletion, and trusted-device identity.
- Replace questionable or template-like visual assets with a new original GhostStream 2.0 asset package.
- Remove or retire unused legacy branded assets such as `APKBrandLogo`, `APKPattern`, and any other assets that do not belong to the new product identity.
- Preserve third-party playback frameworks only where functionally appropriate and legally distributable.
- Avoid shipping any third-party provider branding or bundled content.
- Keep user-provided playback sources empty by default.

## 3. Platforms

GhostStream 2.0 will support:

- iPhone
- iPad
- Apple TV
- GhostStream web account/deletion portal at `ghoststreams.ink`
- self-hosted GhostStream backend on the existing Ubuntu/Docker server

The iPhone, iPad, and Apple TV applications share the same account and sync model while using device-appropriate layouts.

## 4. Primary information architecture

The product must no longer use Live / Movies / Series / Sources as the top-level conceptual structure.

Primary areas:

### 4.1 Dashboard / Home

The Dashboard is the central control surface.

It includes:

- GhostStream account status
- connected source status
- trusted-device summary
- Continue Watching
- recently used sources
- source health summary
- quick access to Live TV, Movies, and Series
- recent diagnostic alerts
- pairing shortcut
- Settings shortcut

On iPhone, this is presented as a compact touch-native dashboard.

On iPad, it uses the same hierarchy with more diagnostic and activity detail visible at once.

On Apple TV, the home experience emphasizes:
- Continue Watching
- Live TV
- Movies
- Series
- connected devices
- source health status

### 4.2 Devices

The Devices section shows every device associated with the GhostStream account.

Each device record includes:

- device display name
- device class
- operating system
- last seen
- trusted / pending / revoked state
- current sync status
- whether local source credentials are available on that device

Actions:

- pair new device
- rename device
- revoke device
- re-authorize device
- send selected source to another trusted device
- inspect last synchronization state

### 4.3 Source Intelligence

Source Intelligence is a first-class product area.

It must provide:

- source online/offline state
- source health score
- response time
- playback latency
- measured bitrate
- resolution
- codec
- audio codec
- container
- buffering-event history
- last successful source refresh
- device compatibility
- playback failures
- categorized error causes
- source health history
- corrective recommendations

The product should explain diagnostic results in user-friendly language, e.g.:

- “Source is reachable but responding slowly.”
- “Video codec is supported on this device.”
- “Repeated buffering appears to be network-related.”
- “This stream is unavailable from the provider.”
- “Container is playable through the compatibility player.”
- “Authentication failed. Re-enter this source’s credentials.”

Diagnostics must not expose raw provider passwords.

### 4.4 Sources

Sources are user-controlled service profiles.

Supported source types remain:

- Playlist URL
- imported M3U file
- pasted M3U content
- Provider Login
- direct stream where applicable

Source cards show:

- user-assigned source name
- connection state
- latest health result
- last refresh
- content categories available
- devices carrying this source’s local credentials

Actions:

- connect
- disconnect
- edit
- diagnose
- securely send to trusted device
- delete

Deleting a source removes its local Keychain secret and source-specific cached data.

### 4.5 Activity / Continue Watching

Activity synchronizes across signed-in devices.

It contains:

- Continue Watching
- recent playback
- episode progress
- movie progress
- recently viewed live content where appropriate
- last-used device
- last-played timestamp

Users can clear individual entries or clear their activity history.

### 4.6 Library

Live TV, Movies, and Series remain available as library capabilities.

They are no longer the primary definition of the app.

Library areas include:

- Live TV
- Movies
- Series
- Favorites
- Search
- Categories

All content comes from sources explicitly added by the user.

GhostStream does not bundle or sell channels, movies, series, subscriptions, playlists, provider accounts, or credentials.

## 5. Authentication

GhostStream 2.0 uses both:

1. Email + password
2. Sign in with Apple

The GhostStream backend owns the canonical account record.

### 5.1 Email/password

Account functions:

- create account
- verify email
- sign in
- sign out
- reset password
- change password
- delete account

Passwords are stored server-side only as strong salted password hashes.

### 5.2 Sign in with Apple

The backend accepts Apple identity tokens and links them to the GhostStream account.

The design must support:

- new account creation through Apple
- returning user login
- Apple private relay email addresses
- account linking where appropriate
- account deletion independent of login method

## 6. Backend

The backend will be self-hosted at `ghoststreams.ink` using:

- FastAPI
- PostgreSQL
- Docker
- Nginx reverse proxy
- HTTPS
- structured migrations
- background cleanup jobs where needed

### 6.1 Core backend entities

At minimum:

#### User
- id
- email
- email verification state
- password hash, nullable for Apple-only users
- Apple subject identifier, nullable
- created_at
- deleted_at / deletion state

#### Device
- id
- user_id
- display_name
- platform
- OS version
- device public key
- trust state
- created_at
- last_seen_at
- revoked_at

#### Session
- id
- user_id
- device_id
- refresh token hash
- created_at
- expires_at
- revoked_at

#### SourceProfile
Cloud metadata only.

May contain:
- id
- user_id
- source display name
- source type
- sanitized capability metadata
- source fingerprint / non-secret identifier
- created_at
- updated_at

Must not contain:
- provider password
- raw credential bundle
- unencrypted source secret

#### Favorite
- user_id
- source profile id
- content kind
- content identifier
- timestamps

#### PlaybackProgress
- user_id
- source profile id
- content kind
- content identifier
- position
- duration
- completed state
- last device id
- updated_at

#### DiagnosticSnapshot
Sanitized only:
- source profile id
- device class
- health score
- response time
- latency
- bitrate
- resolution
- codec
- audio codec
- container
- error category
- compatibility result
- timestamp

No raw source URL or credential is stored in this record.

#### PairingSession
- id
- initiating device
- target device / temporary target
- six-digit pairing code hash
- QR pairing token hash
- expiration
- state
- created_at

## 7. Session and token model

Use:

- short-lived access tokens
- rotating refresh tokens
- refresh tokens bound to a device session
- server-side session revocation
- immediate revocation during account deletion
- immediate revocation when a device is removed

Secrets must not be written to application logs.

## 8. Trusted-device identity

Every signed-in device generates its own cryptographic identity locally.

The device stores:

- private device key in Keychain / protected local storage
- public device key registered with GhostStream backend

The backend stores only the public key and trust relationship.

A device must be explicitly trusted before it can receive source credentials from another device.

## 9. Pairing

GhostStream supports both:

- QR pairing
- 6-digit code fallback

### 9.1 Pairing flow

Example Apple TV flow:

1. User opens Devices > Pair Device on Apple TV.
2. Apple TV requests a short-lived pairing session from the backend.
3. Apple TV displays:
   - QR code
   - 6-digit code
   - expiration timer
4. User opens GhostStream on an already trusted iPhone/iPad.
5. User scans the QR code or enters the 6-digit code.
6. Backend verifies both devices are associated with the same authorized account flow.
7. Trusted device confirms the new device.
8. Devices exchange/verify public keys.
9. Apple TV becomes trusted.
10. User can choose which source profiles to transfer.

Pairing codes must expire automatically and be single use.

## 10. Credential transfer

Provider/source credentials must not be persisted in the GhostStream cloud.

### 10.1 Storage

On iPhone/iPad/tvOS:

- provider passwords and sensitive source secrets are stored in Keychain or equivalent protected local storage
- source metadata may be stored locally
- cloud stores only sanitized non-secret source metadata

### 10.2 Device-to-device transfer

When the user transfers a source to a trusted device:

1. Sender obtains recipient device public key.
2. Sender encrypts a one-time credential package for the recipient.
3. Backend may relay opaque ciphertext or assist rendezvous.
4. Backend cannot decrypt the credential package.
5. Recipient decrypts locally.
6. Recipient stores credential in its protected local store.
7. Transfer payload expires and is deleted.

Preferred implementation should use standard Apple/platform cryptographic APIs rather than custom cryptography.

## 11. Source Intelligence engine

The diagnostic engine runs primarily on-device.

### 11.1 Raw inputs that stay local

- raw source URL
- provider username/password
- playlist body
- provider API responses containing secrets
- authorization headers

### 11.2 Sanitized results that may sync

- source profile id
- health score
- response time
- latency
- bitrate
- resolution
- codec/container
- buffering count/rate
- compatibility classification
- normalized error category
- timestamps

### 11.3 Health score

The health score should be explainable, not arbitrary.

It can combine:

- connection success
- response time
- stream start latency
- buffering frequency
- bitrate stability
- decoder compatibility
- repeated request failures

The UI must show the reason behind the score.

## 12. Diagnostic recommendations

Recommendations must be factual and actionable.

Examples:

- reconnect this source
- re-enter credentials
- retry provider refresh
- switch playback compatibility mode
- verify network connection
- try the same stream on another trusted device
- source is responding slowly
- provider returned an unavailable-resource response

Do not claim a provider outage unless the evidence supports it.

## 13. Cross-device sync

Cloud sync includes:

- favorites
- playback progress
- Continue Watching
- recent activity
- trusted device metadata
- sanitized source metadata
- sanitized diagnostic history
- pairing state
- account settings

Cloud sync excludes:

- provider passwords
- raw source credentials
- raw playlist bodies
- authorization headers

### 13.1 Conflict handling

Use last-write-wins for simple settings.

Playback progress should prefer the most recently updated valid position.

Deletion/revocation always wins over synchronization.

## 14. Player

The enhanced player must retain and polish the existing playback capabilities:

- play/pause
- back
- full timeline for VOD
- -10 / +10
- playback speed 0.5x–2x
- aspect fit/fill
- audio-language track selection
- subtitle/CC track selection
- restart from beginning
- resume from last position
- next episode
- previous episode
- auto-play next episode
- episode information
- live playback
- compatibility playback where needed

Playback progress updates the cross-device progress service.

The UI must remain GhostStream-branded and must not expose VLC or other third-party player branding.

## 15. Apple TV experience

Apple TV is a first-class trusted device.

Primary TV areas:

- Home
- Continue Watching
- Live TV
- Movies
- Series
- Devices
- Source Health / status
- Settings

Pairing screen must match the approved concept:

- large GhostStream branding
- QR code
- 6-digit code
- code expiration
- clean instructions

Siri Remote focus behavior must be native and predictable.

## 16. iPhone experience

Primary navigation follows the new GhostStream product model.

Recommended bottom-level structure:

- Home
- Library
- Devices
- Intelligence
- More

The exact labels may adapt to fit, but the old app must not revert to Live / Movies / Series / Sources as its conceptual primary navigation.

Home shows:

- account/device state
- Continue Watching
- source health
- quick library access
- recent activity

## 17. iPad experience

iPad uses the same information architecture but takes advantage of the larger screen.

It should show:

- wider content rails
- source intelligence detail
- device list / detail
- richer health/history charts
- full-screen playback without an unnecessary persistent sidebar during video

## 18. Visual design

The approved visual direction is mandatory.

Core style:

- very dark navy/black background
- purple/indigo accent system
- subtle glow
- thin borders
- rounded cards
- high-contrast white type
- restrained use of gradients
- clean technical diagnostic panels
- GhostStream wordmark and icon
- consistent iconography
- polished multi-device continuity

The app should feel like a premium streaming control platform rather than an IPTV template.

### 18.1 Asset reset

Create a new original GhostStream 2.0 asset package for:

- app icon
- wordmark
- dashboard hero
- device icons/illustrations where custom artwork is needed
- diagnostic graphics
- pairing artwork
- empty-state artwork
- App Store screenshots/featured assets later

Audit legacy assets and remove those that are obsolete, generic, inherited, or confusing.

## 19. Privacy model

Privacy principles:

- no bundled provider credentials
- no provider credential storage in GhostStream cloud
- raw source URLs remain local unless technically required for a user-requested operation
- sanitized diagnostic sync only
- explicit user control over source deletion
- clear description of synced data
- all transport over HTTPS
- sensitive local values in Keychain/protected storage
- account data deletable from app and website

## 20. Account deletion

Account deletion is a global destructive action.

Available from:

- iPhone/iPad Settings > Account > Delete Account
- Apple TV Account/Settings flow where practical
- existing GhostStream website deletion page

### 20.1 Confirmation

The app must clearly explain that account deletion removes:

- GhostStream account
- cloud favorites
- cloud playback history
- playback progress
- paired device records
- sanitized diagnostic history
- synchronized source metadata
- sessions and tokens

It also instructs all signed-in devices to erase GhostStream local data.

### 20.2 Server deletion sequence

1. User re-authenticates where appropriate.
2. Server marks account deletion in progress.
3. All sessions are revoked.
4. Device records are marked for wipe/revocation.
5. Sync payload exposes a deletion tombstone to devices.
6. User-owned cloud records are deleted.
7. Account identity data is deleted except any minimal records legally required to retain.
8. Website and app return a deletion confirmation.

### 20.3 Device wipe

On receipt of deletion state, every GhostStream device erases:

- saved sources
- Keychain credentials
- local source metadata
- favorites
- watch history
- playback progress
- cached libraries
- cached EPG
- diagnostic history
- pairing information
- account/session tokens
- synchronization state

The device returns to the signed-out welcome screen.

If a device is offline during deletion, the server keeps a deletion/revocation tombstone long enough to ensure the device cannot resume a stale session. On reconnect, it must wipe before allowing any authenticated GhostStream use.

## 21. Website integration

The existing GhostStream account deletion website remains part of the product.

It will use the same account backend as the apps.

Website functions:

- authenticate user
- show deletion warning
- submit deletion
- display completion state
- link to support/privacy information

The website must not merely submit an email request if direct deletion is technically available.

## 22. Error handling

All new subsystems need explicit states.

Examples:

### Auth
- invalid credentials
- email unverified
- expired session
- Sign in with Apple failure
- network unavailable

### Pairing
- expired code
- invalid code
- already paired
- device revoked
- pairing canceled
- transfer failed

### Source intelligence
- DNS/network failure
- HTTP failure
- authentication failure
- malformed playlist
- unsupported media
- provider timeout
- codec compatibility issue

### Sync
- offline
- retry pending
- stale token
- account deleted
- conflict resolved

The UI should use human-readable messages with optional technical detail.

## 23. Migration from current GhostStream

Existing local users should not be forced to lose valid local sources during a normal app upgrade.

Migration strategy:

1. Detect legacy local source storage.
2. Migrate provider passwords into the current protected credential store if needed.
3. Preserve legacy sources locally.
4. After account sign-in, ask the user whether to associate/mirror source metadata with the GhostStream account.
5. Never upload raw passwords during migration.
6. Rebuild app navigation around the new dashboard.
7. Remove obsolete old-home code after migration is stable.

Account deletion is the exception: it intentionally erases all GhostStream data across devices.

## 24. New code boundaries

The rebuild should separate responsibilities into focused modules.

Suggested app-side components:

- `AuthService`
- `AccountStore`
- `DeviceIdentityService`
- `DeviceRegistryStore`
- `PairingService`
- `CredentialTransferService`
- `SourceRepository`
- `SourceDiagnosticsService`
- `DiagnosticHistoryStore`
- `SyncEngine`
- `PlaybackProgressStore`
- `ActivityStore`
- `GlobalDeletionCoordinator`
- `GhostStreamAPIClient`

Suggested UI feature modules:

- Dashboard
- Authentication
- Devices
- Pairing
- Source Intelligence
- Sources
- Activity
- Library
- Player
- Account/Settings

Avoid putting the new system into one oversized root Swift file.

## 25. Backend API families

The implementation plan should define concrete routes under versioned APIs.

Expected groups:

- `/api/v1/auth/*`
- `/api/v1/account/*`
- `/api/v1/devices/*`
- `/api/v1/pairing/*`
- `/api/v1/sync/*`
- `/api/v1/sources/*`
- `/api/v1/diagnostics/*`
- `/api/v1/activity/*`
- `/api/v1/deletion/*`

Exact routes and payloads belong in the implementation plan.

## 26. Testing strategy

Implementation must include automated and device testing.

### 26.1 App tests

- auth-state transitions
- source migration
- Keychain read/write/delete
- pairing-code lifecycle
- device trust transitions
- encrypted credential transfer package handling
- source diagnostic classification
- health score calculation
- sync conflicts
- playback progress sync
- account deletion
- global local wipe

### 26.2 Backend tests

- account creation/login
- token rotation
- device registration/revocation
- pairing expiration
- pairing single-use behavior
- sync authorization boundaries
- no credential fields accepted into cloud storage
- sanitized diagnostics only
- deletion cascade
- revoked sessions cannot refresh
- deleted account cannot access prior data

### 26.3 End-to-end tests

At minimum test:

1. Create account on iPhone.
2. Pair Apple TV by QR.
3. Add source on iPhone.
4. Transfer credentials to Apple TV.
5. Play content on Apple TV.
6. Resume on iPhone/iPad.
7. Run diagnostics.
8. Verify sanitized history appears on another device.
9. Delete account on website.
10. Reconnect all devices and verify all local GhostStream data is wiped.

Also test deletion initiated in-app.

## 27. App Review presentation

The final App Review build should make the new differentiation obvious within the first few minutes.

Review walkthrough should demonstrate:

- account sign-in
- dashboard
- Devices
- QR/code pairing
- Source Intelligence
- diagnostic result
- source management
- cross-device progress
- playback
- in-app account deletion entry point

Review notes should state clearly:

- no content/subscriptions/providers are bundled or sold
- credentials are user-provided
- provider credentials are not stored in GhostStream cloud
- demo content is developer-owned
- diagnostic data synced to cloud is sanitized
- account deletion is available in-app and on the website

## 28. Non-goals for the first implementation

To keep the initial rebuild focused, do not add unless later approved:

- Android support
- Windows/macOS client
- social/community feeds
- public provider marketplace
- provider discovery directory
- GhostStream-hosted commercial media catalog
- advertising
- subscription billing
- AI-generated content recommendations

## 29. Definition of done

GhostStream 2.0 is ready for an App Store submission candidate when:

- the approved GhostStream 2.0 visual system is implemented across iPhone/iPad/Apple TV
- the old primary navigation concept is replaced
- account creation/login works with email/password and Sign in with Apple
- trusted-device registration works
- QR + 6-digit pairing works
- provider credentials remain out of cloud storage
- encrypted trusted-device transfer works
- Source Intelligence works with explainable diagnostics
- sanitized diagnostic history syncs
- favorites and playback progress sync
- Continue Watching works across devices
- website and in-app deletion use the same backend deletion path
- account deletion revokes sessions and causes all devices to wipe local GhostStream data
- legacy source migration is tested
- obsolete/template-like assets are removed or replaced
- tests pass
- physical-device verification is complete
- review demo content and credentials remain lawful and functional
