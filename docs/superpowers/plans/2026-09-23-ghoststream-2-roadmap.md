# GhostStream 2.0 Implementation Roadmap

**Spec:** `docs/superpowers/specs/2026-09-23-ghoststream-2-architecture-design.md`

Implement in this order:

1. `2026-09-23-ghoststream-2-backend.md`
   - account platform
   - email/password + Sign in with Apple
   - devices/sessions
   - sanitized sync
   - canonical deletion
   - deployment package

2. `2026-09-23-ghoststream-2-client-foundation.md`
   - iPhone/iPad API/session foundation
   - secure device identity
   - account UI
   - new Dashboard / Library / Devices / Intelligence / More shell
   - legacy source migration
   - sync + global wipe

3. `2026-09-23-ghoststream-2-pairing.md`
   - QR + 6-digit pairing
   - tvOS pairing
   - Curve25519 + ChaChaPoly credential transfer
   - opaque encrypted relay
   - device revoke/send-source management

4. `2026-09-23-ghoststream-2-completion.md`
   - Source Intelligence engine and UI
   - explainable health scoring
   - cross-device Continue Watching
   - full iPhone/iPad/tvOS visual rebuild
   - original asset reset
   - in-app + web deletion
   - privacy manifests
   - App Store review walkthrough and end-to-end release gate

## Execution rule

Each plan is implemented task-by-task with tests first, verification before each completion claim, and a commit at each independently testable boundary. A later plan does not begin until the preceding plan's required tests/builds pass.
