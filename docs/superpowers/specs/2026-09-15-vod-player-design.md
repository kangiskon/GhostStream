# GhostStream Movies & Series Player Design

Upgrade VOD playback without changing Live behavior. iOS/iPadOS gets GhostStream-native VOD controls, persistent resume, speed, fit/fill, real AVFoundation media-selection audio/subtitle tracks, and MobileVLCKit track APIs on fallback. Series passes an ordered episode playlist/context to the player for season/episode selection and previous/next/autoplay navigation. tvOS keeps native Siri Remote playback behavior while adding VOD context, persistent resume and episode navigation; AVPlayerViewController provides native audio/subtitle selection while TVVLCKit fallback exposes real tracks through the GhostStream options overlay.

Live player behavior, EPG, and transport-stream fallback remain unchanged.
