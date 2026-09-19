NOTE: VLC frameworks are bundled in this self-contained Xcode 26.5 package. Any older download/manual-install instructions below are superseded.

GHOSTSTREAM — DIRECT EMBEDDED VLC BUILD
=======================================
This edition does NOT use CocoaPods.
Open GhostStream.xcodeproj directly.

The project references Frameworks/MobileVLCKit.xcframework and links the required Apple system frameworks/libraries.
See Frameworks/INSTALL-MOBILEVLCKIT.txt for the one-time framework drop-in step.

Why the binary is not included in this ZIP:
MobileVLCKit's official binary archive is about 257 MB and must be downloaded from VideoLAN. The project itself is fully configured for direct integration once that folder is dropped in.
