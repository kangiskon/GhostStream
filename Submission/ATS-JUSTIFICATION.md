# ATS exception — App Review justification draft (owner confirmation required)

Both the iOS/iPadOS and tvOS Info.plist files currently include `NSAppTransportSecurity > NSAllowsArbitraryLoads = YES`. This intentionally remains in the project: GhostStream connects to arbitrary user-configured Xtream/M3U provider hostnames, not a fixed developer-controlled domain list. Some compatible providers expose metadata, playlist and playback endpoints over HTTP only. Restricting ATS to media alone would block HTTP playlist/provider login/API requests and would cause already-supported user-entered services to fail; hard-coding exception domains cannot cover arbitrary user-configured hosts.

Suggested text for the App Store Connect ATS justification field, **after confirming actual provider behavior**:

"GhostStream is a general-purpose media player and does not supply streaming services. Users enter their own third-party server or M3U playlist URLs. Some user-configured servers support only HTTP for authentication/playlist metadata as well as media. Because these domains cannot be known at build time, the app currently needs NSAllowsArbitraryLoads to permit connecting to user-selected sources. HTTPS URLs remain supported and preferred; users must provide their own authorized content. We intend to narrow exceptions as provider support permits."

This is a review explanation, NOT advance permission or an approval guarantee. Do not claim traffic is encrypted when it uses HTTP. Apple's ATS guidance recommends minimizing exceptions and requires justification for NSAllowsArbitraryLoads.

Reference: https://developer.apple.com/documentation/security/preventing-insecure-network-connections
