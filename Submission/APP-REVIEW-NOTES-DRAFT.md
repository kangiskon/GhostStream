# GhostStream — App Review notes DRAFT (paste only after replacing fields)

App: GhostStream for iPhone/iPad and Apple TV. Release project: Xcode 26.6 source package. Not a compiled/signed IPA.

**Purpose:** GhostStream is a general-purpose player for user-provided IPTV/M3U/Xtream or single-stream sources. The app does not include a subscription service, content catalog, preloaded channel/movie/series catalog, provider account, or supplied copyrighted content. Users must enter authorized sources.

**Reviewer test access — REQUIRED:**
- [REPLACE BEFORE SUBMISSION: provide a working, legal demo source under your control, exact steps for opening Sources and connecting, and any temporary username/password via the secure App Review fields. Do not include real customer accounts.]
- [REPLACE BEFORE SUBMISSION: demonstrate Live TV, Movies, Series/Next Episode, favorites, source deletion, and whether the demo supports both iOS and tvOS.]
- [REPLACE BEFORE SUBMISSION: if a source needs geographic restrictions or server availability, describe; avoid short-lived/nonworking links.]
- [REPLACE BEFORE SUBMISSION: provide written evidence/licenses for any third-party content, artwork, trademarks or APIs shown to reviewers if Apple requests it.]

**Privacy:** Provider source settings and app preferences are stored on the device; compatible provider passwords use Apple Keychain. The app sends connection and media requests to the user-selected provider. HTTPS is supported but a general ATS exception remains for user-entered HTTP-only metadata/stream endpoints. See `ATS-JUSTIFICATION.md`. App-target privacy manifests describe first-party UserDefaults use. **Third-party VLC privacy practices still require independent audit**; see `SDK-PRIVACY-AUDIT.md`.

**Policy:** [REPLACE BEFORE SUBMISSION: live HTTPS privacy-policy URL; same URL must be accessible inside the app, and the tvOS App Privacy policy text must be filled in App Store Connect.]

**Support:** [REPLACE BEFORE SUBMISSION: public support URL and reachable support email].

**Final test record:** [REPLACE BEFORE SUBMISSION: macOS Xcode 26.6 Archive validation results, privacy report, TestFlight results for real iPhone/iPad/Apple TV devices and reviewer steps].

Do not state that all Apple requirements have been met merely because the source ZIP parses. Approval is Apple's decision.
