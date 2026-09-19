# GhostStream Xcode 26.6 — Privacy compliance source update

This is a source project, **not a signed, validated App Store build**.

## Updated files

- `GhostStream/PrivacyInfo.xcprivacy`, `GhostStreamTV/PrivacyInfo.xcprivacy` and matching Xcode project resource memberships: first-party UserDefaults (CA92.1) declarations, no app-owned tracking declared based on reviewed Swift code; third-party binaries require independent audit.
- `GhostStream/Info.plist`: removed unsupported background-audio capability; existing broad ATS allowance intentionally retained to preserve arbitrary user-provided HTTP provider endpoints (see ATS-JUSTIFICATION).
- `GhostStream/Views/SettingsView.swift`: clearer in-app privacy information about local storage and providers; **this is not a replacement for the published policy link**.
- `regression_app_store_privacy.py`: source-only privacy guard checks.
- `Submission/PRIVACY-POLICY-DRAFT.md`: owner-reviewed editing draft, NOT publication-ready.
- `Submission/APP-REVIEW-NOTES-DRAFT.md`: fill-in review notes.
- `Submission/ATS-JUSTIFICATION.md`: explanation of the retained HTTP exception.
- `Submission/SDK-PRIVACY-AUDIT.md`: unresolved VLC privacy provenance/SDK requirements.
- `Submission/RELEASE-CHECKLIST.md`: actions remaining before App Store submission.

## How to proceed on Mac

1. Open `GhostStream.xcodeproj` in Xcode 26.6, build and test universal iOS/iPad target. Open `GhostStreamTV.xcodeproj`, build and test tvOS target. Confirm both archive to a real device destination.
2. Confirm both privacy manifests are present in the **built app bundles** at the app root. Generate Xcode App Privacy Report from Archives > Distribute App workflow and inspect embedded VLC frameworks too.
3. Review and replace bracketed draft values, confirm all production data practices, publish the final policy to HTTPS; enter the URL in App Store Connect and add a working link inside the app. tvOS also requires its App Privacy policy text.
4. Independently audit the embedded VLC binary SDKs, confirm media rights, provide authorized working test source and review notes; complete the remaining release checklist.

No unpublished policy URL, developer identity, support email, legal test account or framework privacy declarations were invented. The archived app, network behavior, code-signing and App Store approval have **not** been verified here.
