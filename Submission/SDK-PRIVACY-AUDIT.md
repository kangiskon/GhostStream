# Third-party framework privacy audit — BLOCKED until reviewed on macOS

Inspected the supplied ZIP for privacy manifests. No `PrivacyInfo.xcprivacy` is present inside either MobileVLCKit.xcframework or TVVLCKit.xcframework. The first-party app manifests added in this update do NOT assert facts about those binaries. Apple requires a third-party SDK to include its own declarations if it uses required-reason APIs or collects data, and certain listed SDKs require manifests/signatures.

Before publishing:

1. Record the actual publisher, provenance, license, version and binary hashes for every embedded VLC slice and any statically included third-party components; confirm there is no repackaged SDK on Apple's required list. Review Apple's current list: https://developer.apple.com/support/third-party-SDK-requirements/ .
2. Prefer an up-to-date, authenticated vendor release with accurate SDK privacy manifests and signatures where required. Do not fabricate a vendor manifest or modify/supply a signature attributed to that vendor.
3. Inspect framework binaries for required-reason API use and network/telemetry, consult vendor notices, and generate Xcode's App Privacy Report from an actual archive. Inspect all Frameworks and nested binaries in the final .xcarchive, not just this source ZIP.
4. Reconcile actual production data practices with the app's own manifests and App Store Connect disclosures; no-collection/no-tracking is NOT verified for bundled VLC binaries.
5. Check whether app distributions require extra codec or open-source license acknowledgements; existing Licenses directory does not establish all licensing rights or media distribution rights.

Apple sources:
- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/support/third-party-SDK-requirements/
