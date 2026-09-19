# GhostStream pre-submission checklist — release is NOT yet verified

## Applied to the Xcode project
- [x] Added `GhostStream/PrivacyInfo.xcprivacy` to the iOS/iPadOS app target resources.
- [x] Added `GhostStreamTV/PrivacyInfo.xcprivacy` to the tvOS app target resources.
- [x] Declared first-party `UserDefaults` required-reason category with `CA92.1` (local app settings/favorites/resume).
- [x] Removed unused iOS `UIBackgroundModes=audio` declaration; do not claim background playback unless implemented and retested.
- [x] Kept the original ATS compatibility exception and documented its scope/justification. No unsupported claim of HTTPS for all providers.
- [x] Wrote draft policy, review notes and SDK audit guidance.

## Must be completed by app owner / on a Mac
- [ ] Confirm legal name, support/privacy contact, every fact and unresolved bracket in `PRIVACY-POLICY-DRAFT.md`; obtain appropriate legal review as needed.
- [ ] Publish finalized policy at a working, public HTTPS URL and add it to App Store Connect and an easily accessible in-app policy link; ensure tvOS has its required policy text. No URL was invented or added in this package.
- [ ] Independently audit MobileVLCKit and TVVLCKit binaries; check Apple SDK-required manifest/signature list, third-party data collection, network/telemetry and licensing. Upgrade to verified binaries if needed.
- [ ] Confirm no additional server-side logs, analytics, ad SDKs or developer-operated APIs outside this reviewed source; answer App Store Connect App Privacy for *all* platforms and third-party partners honestly.
- [ ] Confirm whether background playback is truly needed. If so, explicitly implement and test before restoring the background audio mode.
- [ ] Verify permitted/authorized test streams and obtain required content rights; provide a reliable demo login, test instructions and license evidence for App Review.
- [ ] Finalize App Store screenshots/text with rights-cleared art, no placeholders or unsupported claims; publish a support URL.
- [ ] Run both targets with Xcode 26.6 on iPhone, iPad, Apple TV and TestFlight; test Source connection, playback, player fallback, subtitles, episode switching, scrolling and deletion. Resolve any build/crash warnings.
- [ ] Archive/Validate each target; generate Xcode App Privacy Report and inspect resulting app and framework bundles for valid manifests; check Apple upload messages.
- [ ] Confirm App Store Connect ATS justification, export-compliance questions, signing, privacy policy URL/text, age ratings, IAP/content rights and account deletion requirements as applicable.

Apple docs:
- https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- https://developer.apple.com/documentation/security/preventing-insecure-network-connections
- https://developer.apple.com/app-store/review/
