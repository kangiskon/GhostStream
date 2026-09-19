# Ghost Stream (iOS)

A neutral SwiftUI IPTV player for iOS 16+. Like VLC, Ghost Stream is a general
media utility: it ships with **no channels, playlists, content, or credentials**.
Everything is provided by *you* at runtime via your own M3U playlist or your own
Xtream Codes account.

- **Display name:** Ghost Stream
- **Bundle ID:** `com.ghostapk.ghoststream.ios`
- **Min iOS:** 16.0
- **UI:** SwiftUI + MVVM, dark theme, purple accent `#7C5CFF`
- **Tabs:** Live · Movies · Series · Search · Settings

---

## Opening & building in Xcode

1. **Open the project**
   ```
   open GhostStream.xcodeproj
   ```
   (Prepared for Xcode 26.5; deployment remains iOS/tvOS 16.0.)

2. **Set your signing team**
   - Select the **GhostStream** project in the navigator.
   - Select the **GhostStream** target → **Signing & Capabilities**.
   - Set **Team** to your Apple Developer team.
   - `CODE_SIGN_STYLE` is already **Automatic**. If the bundle id is taken,
     change `PRODUCT_BUNDLE_IDENTIFIER` to a unique reverse-DNS id you own.

3. **Build & run**
   - **Simulator:** pick any iOS 16+ simulator and press **⌘R**.
   - **Device:** connect an iPhone/iPad, select it as the run destination,
     ensure it's registered with your team, then **⌘R**.

4. **First run**
   - The app opens an empty **Add Source** form. Enter either:
     - an **M3U/M3U8** URL (or paste M3U text), or
     - **Xtream Codes** credentials: Server URL + Username + Password.
   - Optionally add an XMLTV EPG URL. For Xtream sources the EPG endpoint
     (`xmltv.php`) is derived automatically if you leave it blank.

---

## App Icon

`Assets.xcassets/AppIcon.appiconset` contains a single-size (1024×1024)
placeholder slot. Drop your own `1024×1024` PNG into that image set before
submitting to the App Store. `AccentColor` is preconfigured to `#7C5CFF`.

---

## Project layout

```
GhostStream/
  GhostStreamApp.swift        # @main App, theme constants
  Models/
    Models.swift              # Source, Channel, Category, VODStream, Series, Episode, EPGProgramme
  Parsers/
    M3UParser.swift           # #EXTM3U / #EXTINF attribute parser
    XMLTVParser.swift         # SAX XMLTV parser + gzip inflate
  Services/
    XtreamClient.swift        # async Xtream Codes API client + Codable models
    SourceStore.swift         # local persistence of user sources (UserDefaults)
    EPGService.swift          # EPG fetch/cache + nowPlaying/upcoming
    LibraryViewModel.swift    # loads channels/movies/series for the active source
  Views/
    RootTabView.swift         # bottom tab bar + first-run Add Source sheet
    LiveView.swift            # live channels + EPG now-playing
    MoviesView.swift          # VOD poster grid
    SeriesView.swift          # series grid + season/episode detail
    SearchView.swift          # cross-content search
    SettingsView.swift        # manage sources, EPG refresh, about
    AddSourceView.swift       # empty first-run source form
    PlayerView.swift          # AVKit player + "Open in VLC" fallback
  Assets.xcassets             # AppIcon placeholder + AccentColor (#7C5CFF)
  Info.plist                  # ATS arbitrary loads, LSApplicationQueriesSchemes vlc, display name
```

---

## Playback notes

- Playback uses **AVKit** (`VideoPlayer` / `AVPlayer`). iOS decodes **HLS**
  natively and handles many **MPEG-TS/MP4** streams.
- For containers/codecs iOS can't decode natively (MKV, AVI, some HEVC), the
  player offers an **Open in VLC** button that hands the stream URL to the VLC
  app via the `vlc://` scheme. If VLC isn't installed, the user is taken to its
  App Store page. `vlc` is declared in `LSApplicationQueriesSchemes`.
- `NSAppTransportSecurity → NSAllowsArbitraryLoads = true` is set so
  user-provided **http** IPTV streams can load. This mirrors general-purpose
  media players and is justified because the app plays arbitrary user URLs.

---

## App Store compliance / review notes

> Paste the following into **App Store Connect → App Review → Notes** (adapt as needed).

**What the app is.** Ghost Stream is a neutral media player, comparable to VLC.
It contains no channels, no playlists, no streaming content, and no account
credentials. The binary ships empty.

**How content is provided.** All media is supplied by the user at runtime. On
first launch the app shows an empty "Add Source" form. The user must enter
**their own**:
- an M3U/M3U8 playlist URL (or paste M3U text), **or**
- Xtream Codes login details (server URL, username, password) for **their own**
  subscription/service.

**No bundled or default sources.** There are no pre-filled URLs, demo
playlists, hard-coded servers, or embedded credentials anywhere in the app or
its assets. User sources are stored locally on-device only (UserDefaults) and
are never transmitted to us; the app has no backend.

**Reviewer testing.** Because the app ships empty, reviewers can validate the
UI/flow using any public, license-free test playlist they control, or a test
Xtream account they possess. We do not and cannot provide content for testing,
exactly as VLC does not.

**Networking.** Arbitrary-loads ATS is enabled solely to play user-entered
http(s) stream URLs, consistent with general-purpose media players.

**Third-party playback hand-off.** An optional "Open in VLC" action forwards the
user's own stream URL to the VLC app for formats iOS cannot decode. No content
is fetched or stored by Ghost Stream in this flow.

**Content responsibility.** The user is solely responsible for the legality of
any source they add. Ghost Stream neither hosts, curates, aggregates, nor
distributes any media.

---

## Compliance statement

Ghost Stream is a client-side utility that plays media from user-supplied M3U
playlists or user-supplied Xtream Codes accounts. It bundles no content and
provides no default sources. It is functionally analogous to a general media
player such as VLC and is intended only for users to access services they are
already entitled to use.

## Provider HTTP 404 auto-detection fix
- Sanitizes pasted player_api.php/get.php/xmltv.php URLs.
- Tries the entered provider base path, the host root, and alternate HTTP/HTTPS transport when the provider endpoint returns 404 or cannot connect.
- Reuses the discovered working API base for library and generated Live/Movie/Series URLs.
- 404 errors no longer expose username/password query parameters.

## Apple TV playback compatibility

The tvOS player now uses this order:

1. For live `.ts` streams, try the matching `.m3u8` HLS URL with AVPlayer.
2. If HLS fails, retry the original provider URL with AVPlayer.
3. If `TVVLCKit` is added to the GhostStreamTV target, automatically switch to the embedded compatibility engine for formats AVPlayer rejects.

This is especially useful when the Apple TV simulator shows the prohibited/play-slash symbol for an otherwise valid IPTV stream.

### Embedded compatibility engines (VLCKit)

This self-contained package includes VideoLAN 3.6.0 XCFrameworks directly under `Frameworks/`: MobileVLCKit for iPhone/iPad and TVVLCKit for Apple TV. Xcode does not download them during the build. The existing embed/sign phases select the correct platform slice.

License texts from the official VideoLAN binary archives are included under `Licenses/`.
## Apple TV provider-native categories

The tvOS Live TV, Movies, and Series screens use the provider's actual category endpoints/IDs. Xtream categories preserve server order; M3U Live TV uses `group-title`. Empty categories are hidden and filtering uses cached category buckets for large libraries.

