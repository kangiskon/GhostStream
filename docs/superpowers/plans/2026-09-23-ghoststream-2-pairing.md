# GhostStream 2.0 Trusted Device Pairing & Encrypted Credential Transfer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add QR + 6-digit trusted-device pairing and end-to-end encrypted source credential transfer between GhostStream devices without storing provider credentials in the GhostStream cloud.

**Architecture:** The backend creates single-use expiring pairing sessions and relays only opaque encrypted envelopes. Each Apple device has a Curve25519 identity keypair; sender derives a shared key using an ephemeral key and recipient public key, encrypts a credential payload with CryptoKit ChaChaPoly, and recipient decrypts locally into Keychain.

**Tech Stack:** Swift/CryptoKit/Security, SwiftUI, CoreImage QR generation and Vision/AVFoundation scanning on iPhone/iPad, tvOS SwiftUI, FastAPI/PostgreSQL backend.

**Spec:** `docs/superpowers/specs/2026-09-23-ghoststream-2-architecture-design.md`

## Global Constraints

- Pairing supports both QR and 6-digit fallback.
- Pairing sessions are single-use and expire automatically.
- Provider passwords and raw source credentials never appear in backend database rows or logs.
- Recipient must be explicitly trusted before credential import completes.
- Transfer envelope is encrypted for exactly one recipient device and expires.
- Apple TV is a first-class pairing target.

## Review Focus

- Reusing a consumed 6-digit code must fail.
- Scanning an expired QR must show an expired-session state, not create trust.
- Ciphertext captured by the server must be undecryptable without recipient private key.
- Credential envelope targeted at Device B must fail on Device C.
- Revoked device must not receive or decrypt new transfers even if it knows an old pairing id.

---

### Task 1: Backend pairing session API

**Files:**
- Create: `backend/ghoststream_api/routes/pairing.py`
- Create: `backend/ghoststream_api/services/pairing_service.py`
- Create: `backend/tests/test_pairing.py`
- Modify: `backend/ghoststream_api/main.py`

**Interfaces:**
- `POST /api/v1/pairing/sessions`
- `POST /api/v1/pairing/claim`
- `POST /api/v1/pairing/{id}/approve`
- `GET /api/v1/pairing/{id}/state`
- six-digit code stored only as hash; QR token stored only as hash.

- [ ] **Step 1: Write expiry/single-use tests**

Create pairing, claim once, approve, then assert second claim returns 409/410. Advance clock beyond expiry and assert claim fails.

- [ ] **Step 2: Implement cryptographically random pairing material**

Use six decimal digits for manual code plus a separate 256-bit QR token. Hash both before persistence.

- [ ] **Step 3: Require same-account authorization for approval**

Anonymous target may initiate, but trusted source device must authenticate and approve; final registered device attaches to account only after approval.

- [ ] **Step 4: Run tests**

Run: `cd backend && pytest tests/test_pairing.py -q`.

- [ ] **Step 5: Commit**

Commit: `feat(api): add secure device pairing sessions`.

### Task 2: Encrypted relay API

**Files:**
- Create: `backend/ghoststream_api/routes/transfers.py`
- Create: `backend/ghoststream_api/services/transfer_service.py`
- Create: `backend/tests/test_transfer_relay.py`
- Modify: `backend/ghoststream_api/main.py`

**Interfaces:**
- `POST /api/v1/devices/{device_id}/transfers`
- `GET /api/v1/devices/me/transfers`
- `DELETE /api/v1/devices/me/transfers/{id}`
- Envelope fields only: sender id, recipient id, ephemeral public key, nonce/sealed ciphertext, created/expires timestamps.

- [ ] **Step 1: Test forbidden plaintext keys**

Requests containing `password`, `username`, `server_url`, `playlist_body` outside ciphertext are rejected.

- [ ] **Step 2: Test recipient authorization**

Only recipient may fetch envelope; revoked recipient receives 403/410.

- [ ] **Step 3: Implement short retention**

Default envelope expiry: 10 minutes. Successful acknowledgement deletes envelope immediately.

- [ ] **Step 4: Run tests and commit**

Run: `cd backend && pytest tests/test_transfer_relay.py -q`.  
Commit: `feat(api): add opaque credential relay`.

### Task 3: iPhone/iPad pairing scanner and manual code UI

**Files:**
- Create: `GhostStream/Devices/PairDeviceView.swift`
- Create: `GhostStream/Devices/QRCodeScannerView.swift`
- Create: `GhostStream/Devices/DevicesView.swift`
- Create: `GhostStream/Devices/PairingService.swift`
- Create: `regression_ghoststream2_pairing_ui.py`

**Interfaces:**
- `PairingService.claim(qrPayload:)`
- `PairingService.claim(code: String)`
- `PairingService.approve(pairingID:)`.

- [ ] **Step 1: UI regression**

Require scan action, “Enter Code Instead”, six-digit validation, expiration/error display, and explicit approval screen naming target device.

- [ ] **Step 2: Implement scanner**

Use `AVCaptureSession` metadata QR scanning. Payload contains only HTTPS-safe pairing id/token, no account password or provider data.

- [ ] **Step 3: Implement manual code**

Accept exactly six ASCII digits; disable submit until valid.

- [ ] **Step 4: Build and regress**

Run iOS xcodebuild + regression script.

- [ ] **Step 5: Commit**

Commit: `feat(ios): add QR and code device pairing`.

### Task 4: Apple TV pairing presentation

**Files:**
- Create: `GhostStreamTV/Pairing/TVPairDeviceView.swift`
- Create: `GhostStreamTV/Pairing/TVPairingService.swift`
- Modify: `GhostStreamTV/TVRootView.swift`
- Create: `regression_ghoststream2_tvos_pairing.py`
- Modify: `GhostStreamTV.xcodeproj/project.pbxproj`

**Interfaces:**
- TV requests pairing session and shows `qrPayload`, `manualCode`, `expiresAt`.

- [ ] **Step 1: Regression test**

Require visible GhostStream branding, QR image, six-digit code, expiration message, and cancel/retry states.

- [ ] **Step 2: Generate QR locally**

Use CoreImage `CIQRCodeGenerator` from server-issued payload. Never render credential text in QR.

- [ ] **Step 3: Poll pairing state**

Back off polling; stop on paired/expired/cancelled. On paired state, register/store TV device identity.

- [ ] **Step 4: Build tvOS**

Run:
`xcodebuild -project GhostStreamTV.xcodeproj -scheme GhostStreamTV -sdk appletvsimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`

- [ ] **Step 5: Commit**

Commit: `feat(tvos): add GhostStream device pairing`.

### Task 5: CryptoKit credential envelope

**Files:**
- Create: `GhostStream/Devices/CredentialEnvelope.swift`
- Create: `GhostStream/Devices/CredentialTransferService.swift`
- Create: `GhostStreamTV/Shared/CredentialEnvelope.swift`
- Create: `GhostStreamTV/Shared/CredentialTransferService.swift`
- Create: `regression_ghoststream2_credential_crypto.py`

**Interfaces:**
- `CredentialPayload`: source id/type plus only fields needed to recreate local source.
- `CredentialEnvelope.seal(payload:recipientPublicKey:) -> SealedCredentialEnvelope`
- `CredentialEnvelope.open(_:recipientPrivateKey:) -> CredentialPayload`.

- [ ] **Step 1: Write crypto regression harness**

Add a standalone Swift regression that:
1. creates sender ephemeral + recipient keys
2. seals sample payload
3. opens with recipient
4. verifies wrong private key throws.

- [ ] **Step 2: Implement encryption**

Use Curve25519 key agreement + HKDF-SHA256 + ChaChaPoly. Include sender/recipient ids as authenticated associated data. Generate new ephemeral sender key per transfer.

- [ ] **Step 3: Keep plaintext lifetime narrow**

Decode, save directly into SourceStore/Keychain, then release payload. Do not print payload in logs.

- [ ] **Step 4: Run Swift regression and both builds**

Run compiled Swift regression where available, iOS xcodebuild, tvOS xcodebuild.

- [ ] **Step 5: Commit**

Commit: `feat(core): add encrypted source transfer`.

### Task 6: Devices management and revocation

**Files:**
- Modify: `GhostStream/Devices/DevicesView.swift`
- Create: `GhostStream/Devices/DeviceDetailView.swift`
- Modify: `GhostStream/Account/AccountStore.swift`
- Create: `regression_ghoststream2_device_management.py`

**Interfaces:**
- Rename, revoke, re-authorize, send source, inspect last sync.

- [ ] **Step 1: Add regression expectations**

Require trust badge, platform, OS, last seen, sync status, source-credential availability, revoke action, send-source action.

- [ ] **Step 2: Implement revoke flow**

Confirm destructive action; call backend; delete any pending outbound transfers to revoked device.

- [ ] **Step 3: Implement send-source flow**

User chooses source + trusted device; service encrypts payload and posts opaque envelope.

- [ ] **Step 4: Build/regress and commit**

Commit: `feat(ios): add trusted device management`.
