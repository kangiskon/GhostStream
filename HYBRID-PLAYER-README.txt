GhostStream Hybrid Player
=========================

Playback order:
1. Apple AVPlayer is attempted first for every stream.
2. If AVPlayer reports a playback failure or cannot become ready within the
   preparation grace period, GhostStream automatically switches to the
   embedded compatibility engine when MobileVLCKit is present.

Benefits:
- HLS (.m3u8) and Apple-supported VOD use native iOS playback/hardware decoding.
- Unsupported IPTV/container/codec combinations can still fall back internally.
- GhostStream's own controls remain visible regardless of the active engine.
- No third-party player branding appears in the app UI.

Keep Frameworks/MobileVLCKit.xcframework in the project to enable fallback.
