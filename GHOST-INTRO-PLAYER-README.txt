GhostStream – Ghost Intro + Full-Screen VLC Player
==================================================

This build adds:
- GhostStream ghost startup animation using the included GhostIntro asset.
- Teal/cyan GhostStream visual theme.
- Automatic landscape request when playback opens on iOS 16/Xcode 14.
- Status bar, navigation bar, and tab bar hidden during playback.
- Playback controls overlay that auto-hides after 3 seconds and returns on tap.
- Pause/resume for embedded MobileVLCKit playback.
- Seek timeline for movies and series.
- DVR seek timeline for live streams only when the provider exposes a seekable buffer.
- Automatic return to portrait when the player is closed.

VLC framework:
This project is configured for direct MobileVLCKit integration. Keep:
Frameworks/MobileVLCKit.xcframework
in the project before building. If your copy of the framework is not already there,
follow Frameworks/INSTALL-MOBILEVLCKIT.txt.

Open GhostStream.xcodeproj in Xcode 14.0.1.
