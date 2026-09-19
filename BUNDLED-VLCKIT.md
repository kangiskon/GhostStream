# Bundled VLCKit frameworks

This GhostStream package is self-contained for playback dependencies:

- `Frameworks/MobileVLCKit.xcframework` — iPhone/iPad
- `Frameworks/TVVLCKit.xcframework` — Apple TV

The Xcode projects no longer download these frameworks during a build. The existing Embed phases select the correct device/simulator slice and sign the dynamic framework for device builds.

License texts from the official VideoLAN binary archives are included under `Licenses/`.
