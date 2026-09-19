GhostStream Multi-Device Build

1) iPhone + iPad
Open GhostStream.xcodeproj.
The iOS target now uses safe-area geometry and adaptive widths so the same GhostStream theme scales across iPhone sizes and iPad sizes/orientations. The background artwork is clipped to the device bounds so it cannot make the SwiftUI layout wider than the screen.

2) Apple TV
Open GhostStreamTV.xcodeproj.
This is a dedicated tvOS 16+ target prepared for Xcode 26.5. It uses the same GhostStream branding in a 16:9 layout and Apple TV focus/card navigation. It supports Provider Login (Xtream), M3U URL, saved sources, Live TV, Movies, Series and AVPlayer playback.

Apple TV intentionally does not use the iOS MobileVLCKit framework. It uses native AVPlayer for tvOS playback.

Before building either project, select your Apple Developer Team in Signing & Capabilities.
