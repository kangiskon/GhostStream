# GhostStream 2.0 Backend Identity, Device Registry, Sync & Deletion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the self-hosted GhostStream account backend that supports email/password, Sign in with Apple, device sessions, synchronized user data, and global account deletion without storing provider credentials.

**Architecture:** Add a versioned FastAPI service under `backend/` backed by PostgreSQL and SQLAlchemy/Alembic. Access tokens are short-lived JWTs; refresh tokens are opaque random secrets stored only as hashes. The backend stores account/device/sync metadata and sanitized diagnostic results, while explicitly rejecting provider passwords, raw source credentials, raw playlist bodies, and authorization headers.

**Tech Stack:** Python 3.12, FastAPI, Uvicorn, PostgreSQL, SQLAlchemy 2.x async, asyncpg, Alembic, Pydantic v2, argon2-cffi, PyJWT[crypto], httpx, pytest, pytest-asyncio.

**Spec:** `docs/superpowers/specs/2026-09-23-ghoststream-2-architecture-design.md`

## Global Constraints

- Backend is self-hosted at `ghoststreams.ink` behind Docker + Nginx + HTTPS.
- Authentication supports email/password and Sign in with Apple.
- Provider passwords, raw credentials, raw playlists, authorization headers, and decryptable credential bundles must never be persisted in the GhostStream cloud.
- All account deletion paths use one canonical deletion service.
- Deletion revokes all sessions immediately and leaves only non-personal revocation tombstones required to wipe offline devices on reconnect.
- APIs are versioned under `/api/v1`.
- No bundled content/providers/subscriptions are introduced.

## Review Focus

- Replayed or stolen refresh token: rotation must revoke the token family and deny further refresh.
- Deleted account reconnect from an offline device: backend must return a deletion/revocation signal that causes client wipe rather than silently creating a new session.
- Sign in with Apple private-relay email: identity must key on Apple subject, not mutable email.
- Malicious source payload containing `password`, `authorization`, or raw playlist text: request must be rejected before persistence.
- Two devices updating playback progress concurrently: most recent valid update wins without resurrecting deleted account data.

---

### Task 1: Backend package, configuration, database session, and health endpoint

**Files:**
- Create: `backend/pyproject.toml`
- Create: `backend/ghoststream_api/__init__.py`
- Create: `backend/ghoststream_api/config.py`
- Create: `backend/ghoststream_api/db.py`
- Create: `backend/ghoststream_api/main.py`
- Create: `backend/tests/test_health.py`
- Create: `backend/.env.example`
- Create: `backend/Dockerfile`
- Create: `backend/docker-compose.example.yml`

**Interfaces:**
- Produces: `Settings`, `get_session()`, FastAPI `app`, `GET /health`.

- [ ] **Step 1: Write the failing health test**

```python
from fastapi.testclient import TestClient
from ghoststream_api.main import app

def test_health():
    response = TestClient(app).get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "ghoststream-api"}
```

- [ ] **Step 2: Run the test and verify failure**

Run: `cd backend && pytest tests/test_health.py -q`  
Expected: import or route failure because the backend package does not yet exist.

- [ ] **Step 3: Add minimal configuration and app**

`config.py` exposes a cached Pydantic settings object with exact environment names:
`DATABASE_URL`, `JWT_SECRET`, `ACCESS_TOKEN_MINUTES`, `REFRESH_TOKEN_DAYS`, `APPLE_BUNDLE_ID`, `APPLE_TEAM_ID`.

`main.py`:
```python
from fastapi import FastAPI

app = FastAPI(title="GhostStream API", version="2.0")

@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "ghoststream-api"}
```

- [ ] **Step 4: Run tests**

Run: `cd backend && pytest tests/test_health.py -q`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend
git commit -m "feat(api): add GhostStream backend foundation"
```

### Task 2: User, device, session, sync, diagnostic, and deletion models

**Files:**
- Create: `backend/ghoststream_api/models.py`
- Create: `backend/ghoststream_api/schemas.py`
- Create: `backend/alembic.ini`
- Create: `backend/alembic/env.py`
- Create: `backend/alembic/versions/0001_initial.py`
- Create: `backend/tests/test_model_constraints.py`

**Interfaces:**
- Produces SQLAlchemy models: `User`, `Device`, `Session`, `EmailActionToken`, `SourceProfile`, `Favorite`, `PlaybackProgress`, `DiagnosticSnapshot`, `PairingSession`, `DeletionTombstone`.

- [ ] **Step 1: Write tests that pin secret-free source metadata**

```python
def test_source_profile_schema_rejects_password():
    from pydantic import ValidationError
    from ghoststream_api.schemas import SourceProfileUpsert
    with pytest.raises(ValidationError):
        SourceProfileUpsert(
            source_id="abc",
            display_name="Main",
            kind="provider",
            password="secret",
        )
```

Add equivalent tests for fields named `authorization`, `playlist_body`, and `raw_url`.

- [ ] **Step 2: Run and verify failure**

Run: `cd backend && pytest tests/test_model_constraints.py -q`  
Expected: FAIL because schemas/models are absent.

- [ ] **Step 3: Implement models and schemas**

Use UUID primary keys. Store:
- email normalized lowercase
- `apple_subject` unique nullable
- device public key as base64 text
- refresh-token hashes only
- `SourceProfile` with display name, type, fingerprint, capability metadata only
- `DiagnosticSnapshot` with normalized technical fields only
- `DeletionTombstone` keyed by SHA-256 hash of former device id/session identity, with expiry.

Pydantic schemas use `extra="forbid"` so secret-like fields fail validation instead of being ignored.

- [ ] **Step 4: Generate and apply migration in test database**

Run: `cd backend && alembic upgrade head`  
Expected: all initial tables created.

- [ ] **Step 5: Run tests and commit**

Run: `cd backend && pytest tests/test_model_constraints.py -q`  
Expected: PASS.

Commit: `feat(api): add account device sync data model`.

### Task 3: Email/password auth, verification, recovery, and rotating sessions

**Files:**
- Create: `backend/ghoststream_api/security.py`
- Create: `backend/ghoststream_api/services/auth_service.py`
- Create: `backend/ghoststream_api/routes/auth.py`
- Modify: `backend/ghoststream_api/main.py`
- Create: `backend/tests/test_auth.py`

**Interfaces:**
- Produces:
  - `hash_password(password: str) -> str`
  - `verify_password(password: str, encoded: str) -> bool`
  - `issue_session(user_id: UUID, device_id: UUID) -> TokenPair`
  - `rotate_refresh_token(raw_token: str) -> TokenPair`
  - `issue_email_action(user_id: UUID, kind: str) -> str`
  - routes `POST /api/v1/auth/register`, `/verify-email`, `/login`, `/refresh`, `/logout`, `/forgot-password`, `/reset-password`, `/change-password`.

- [ ] **Step 1: Write auth tests**

Tests cover:
- registration hashes password and creates a one-time email-verification token
- email-verification token is stored only as a hash, expires, and cannot be reused
- login succeeds with valid password
- invalid password returns 401
- forgot-password returns the same public response for existing and non-existing email addresses
- reset token is single-use and invalidates existing sessions after a successful password reset
- authenticated password change requires the current password and revokes other sessions
- stored session contains only SHA-256 refresh hash
- refresh rotates token and invalidates prior raw token
- replay of rotated token revokes token family
- revoked device cannot refresh.

- [ ] **Step 2: Run tests and verify failure**

Run: `cd backend && pytest tests/test_auth.py -q`.

- [ ] **Step 3: Implement Argon2 password hashing and opaque refresh tokens**

Generate refresh and email-action secrets with `secrets.token_urlsafe(48)`; store only `sha256(raw).hexdigest()`. `EmailActionToken` stores user id, action kind (`verify_email` or `reset_password`), expiry, used timestamp, and token hash. JWT access claims include only `sub`, `device_id`, `session_id`, `iat`, `exp`.

- [ ] **Step 4: Implement routes, email actions, and dependency**

Create `current_session()` FastAPI dependency that verifies access token and checks session/device/account revocation state. Registration calls an injectable `EmailSender` interface with the verification link; production implementation uses SMTP values from `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM`, and `PUBLIC_WEB_BASE_URL`. Forgot-password always returns 202 with the same body. Reset/change password revoke existing sessions according to the tests.

- [ ] **Step 5: Run tests and commit**

Run: `cd backend && pytest tests/test_auth.py -q`  
Expected: PASS.

Commit: `feat(api): add email auth and rotating sessions`.

### Task 4: Sign in with Apple

**Files:**
- Create: `backend/ghoststream_api/services/apple_auth.py`
- Modify: `backend/ghoststream_api/routes/auth.py`
- Create: `backend/tests/test_apple_auth.py`

**Interfaces:**
- Produces: `verify_apple_identity_token(token: str) -> AppleIdentity`
- Route: `POST /api/v1/auth/apple`.

- [ ] **Step 1: Write tests using a generated RSA keypair**

Tests verify:
- valid Apple-style token accepted
- wrong audience rejected
- expired token rejected
- same Apple `sub` returns same user even if email changes
- private-relay email is accepted.

- [ ] **Step 2: Run and verify failure**

Run: `cd backend && pytest tests/test_apple_auth.py -q`.

- [ ] **Step 3: Implement Apple JWKS verifier**

Fetch `https://appleid.apple.com/auth/keys` through `httpx`, cache keys by `kid`, verify issuer `https://appleid.apple.com`, audience equal to configured bundle/client id, signature, and expiry. Do not trust an email field without a verified token.

- [ ] **Step 4: Implement account lookup/linking**

Canonical lookup order:
1. verified `apple_subject`
2. explicitly linked authenticated account
3. create new user.

Do not automatically merge solely by matching email.

- [ ] **Step 5: Run tests and commit**

Run: `cd backend && pytest tests/test_apple_auth.py -q`.  
Commit: `feat(api): add Sign in with Apple`.

### Task 5: Device registry and sanitized sync APIs

**Files:**
- Create: `backend/ghoststream_api/routes/devices.py`
- Create: `backend/ghoststream_api/routes/sync.py`
- Create: `backend/ghoststream_api/services/sync_service.py`
- Create: `backend/tests/test_devices_sync.py`
- Modify: `backend/ghoststream_api/main.py`

**Interfaces:**
- Routes:
  - `POST /api/v1/devices/register`
  - `GET /api/v1/devices`
  - `PATCH /api/v1/devices/{id}`
  - `DELETE /api/v1/devices/{id}`
  - `GET /api/v1/sync/pull?since=<cursor>`
  - `POST /api/v1/sync/push`
- Sync types: favorites, playback progress, source metadata, sanitized diagnostics, account settings.

- [ ] **Step 1: Write authorization boundary tests**

User A cannot read/update User B device or sync data. Push with any forbidden secret field returns 422/400. Revoked devices receive 401/403.

- [ ] **Step 2: Write concurrent progress test**

Push two progress records with different `updated_at`; assert the later valid timestamp wins. Reject impossible negative positions and non-finite durations.

- [ ] **Step 3: Implement registry and cursor sync**

Sync cursor is monotonically increasing per user. Deletion/revocation events have precedence over content updates.

- [ ] **Step 4: Run tests**

Run: `cd backend && pytest tests/test_devices_sync.py -q`.

- [ ] **Step 5: Commit**

Commit: `feat(api): add device registry and sanitized sync`.

### Task 6: Canonical account deletion and offline-device tombstones

**Files:**
- Create: `backend/ghoststream_api/services/deletion_service.py`
- Create: `backend/ghoststream_api/routes/account.py`
- Create: `backend/tests/test_deletion.py`
- Modify: `backend/ghoststream_api/main.py`

**Interfaces:**
- Produces:
  - `delete_account(user_id: UUID) -> None`
  - `POST /api/v1/account/delete`
  - `GET /api/v1/account/state`.
- Deleted/revoked device requests return HTTP 410 with body `{"code":"account_deleted"}` when matched by an unexpired tombstone.

- [ ] **Step 1: Write deletion cascade test**

Create user with two sessions, two devices, source metadata, favorite, progress, diagnostics. Delete account. Assert personal rows are gone, sessions unusable, and only hashed tombstones remain.

- [ ] **Step 2: Write offline-device reconnect test**

Use the old refresh token/device id after deletion. Assert HTTP 410 / `account_deleted`.

- [ ] **Step 3: Implement transaction**

Within one transaction:
- hash device/session identifiers into tombstones
- revoke sessions
- delete sync data, source profiles, diagnostics, pairing records
- delete devices
- delete user.

- [ ] **Step 4: Run tests**

Run: `cd backend && pytest tests/test_deletion.py -q`.

- [ ] **Step 5: Commit**

Commit: `feat(api): add global account deletion`.

### Task 7: Deployment packaging and full backend verification

**Files:**
- Create: `backend/nginx-ghoststream-api.conf.example`
- Create: `backend/DEPLOY.md`
- Create: `backend/scripts/smoke_test.sh`
- Modify: `backend/docker-compose.example.yml`

**Interfaces:**
- Deployment keeps API private behind Nginx and exposes only HTTPS routes under `/api/`.

- [ ] **Step 1: Add smoke test script**

Check `/health`, registration/login, device registration, refresh rotation, account state, and delete against a disposable test account.

- [ ] **Step 2: Run full suite**

Run: `cd backend && pytest -q`  
Expected: all tests PASS.

- [ ] **Step 3: Build container**

Run: `docker build -t ghoststream-api:test backend`  
Expected: successful image build.

- [ ] **Step 4: Run container smoke test against local Postgres**

Run the documented Docker Compose command and `backend/scripts/smoke_test.sh`.

- [ ] **Step 5: Commit**

Commit: `chore(api): add deployment and smoke verification`.
