import SwiftUI
import AVKit
import AVFoundation
import UIKit
import QuartzCore

#if canImport(MobileVLCKit)
import MobileVLCKit
#endif

enum PlayerContentKind {
    case live
    case vod
}

struct PlayerMediaTrack: Identifiable, Hashable {
    let id: Int
    let name: String
}

struct SeriesPlaybackContext {
    let seriesID: Int?
    let seriesTitle: String
    let plot: String?
    let episodes: [Episode]
    let initialEpisodeID: String

    init(
        seriesID: Int? = nil,
        seriesTitle: String,
        plot: String?,
        episodes: [Episode],
        initialEpisodeID: String
    ) {
        self.seriesID = seriesID
        self.seriesTitle = seriesTitle
        self.plot = plot
        self.episodes = episodes
        self.initialEpisodeID = initialEpisodeID
    }
}

private enum VODResumeStore {
    static func key(_ id: String) -> String { "ghoststream.resume." + id }
    static func position(for id: String) -> Double { UserDefaults.standard.double(forKey: key(id)) }
    static func save(_ seconds: Double, duration: Double, for id: String) {
        guard seconds > 10, duration > 30, seconds < duration - 20 else { return }
        UserDefaults.standard.set(seconds, forKey: key(id))
    }
    static func clear(_ id: String) { UserDefaults.standard.removeObject(forKey: key(id)) }
}

/// GhostStream hybrid full-screen player.
/// Native AVPlayer is always attempted first for smoother iOS playback.
/// If the stream cannot be opened natively, the embedded compatibility engine
/// is selected automatically (when included in the build).
struct PlayerView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var epg: EPGService
    @EnvironmentObject private var store: SourceStore
    @ObservedObject private var favorites = FavoriteStore.shared
    @ObservedObject private var playbackProgress = PlaybackProgressStore.shared

    let title: String
    let urlString: String
    var kind: PlayerContentKind = .vod
    var epgChannelId: String? = nil
    var contentID: String? = nil
    var seriesContext: SeriesPlaybackContext? = nil

    @State private var isPlaying = false
    @State private var hasPlaybackStarted = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isSeekable = false
    @State private var isScrubbing = false
    @State private var requestedPosition: Double?
    @State private var playbackCommand = 0
    @State private var controlsVisible = true
    @State private var controlsHideWorkItem: DispatchWorkItem?
    @State private var useCompatibilityEngine = false
    @State private var tryOriginalNativeURL = false
    @State private var nativeError: String?
    @State private var liveUtilityMessage: String?
    @State private var playbackRate: Float = 1.0
    @State private var aspectFill = false
    @State private var audioTracks: [PlayerMediaTrack] = []
    @State private var subtitleTracks: [PlayerMediaTrack] = []
    @State private var selectedAudioTrack: Int?
    @State private var selectedSubtitleTrack: Int?
    @State private var trackCommand = 0
    @State private var playbackEndedToken = 0
    @State private var currentEpisodeID: String?
    @State private var autoPlayNext = true
    @State private var showEpisodeInfo = false
    @State private var didRestoreResume = false
    @State private var episodeSwitchInProgress = false
    @State private var lastProgressPublishedAt = Date.distantPast

    private var currentSeriesEpisode: Episode? {
        guard let context = seriesContext else { return nil }
        let id = currentEpisodeID ?? context.initialEpisodeID
        return context.episodes.first(where: { $0.id == id })
    }
    private var effectiveTitle: String { currentSeriesEpisode?.title ?? title }
    private var effectiveURLString: String { currentSeriesEpisode?.url ?? urlString }
    private var streamURL: URL? { URL(string: effectiveURLString) }
    private var resumeID: String { currentSeriesEpisode?.id ?? contentID ?? effectiveURLString }
    private var progressContentID: String? { currentSeriesEpisode?.id ?? contentID }
    private var progressContentKind: PlaybackContentKind { currentSeriesEpisode == nil ? .vod : .episode }
    private let liveAccent = Color(red: 124.0 / 255.0, green: 92.0 / 255.0, blue: 1.0)

    /// Xtream live streams are often exposed as both MPEG-TS and HLS. iOS
    /// generally performs best with HLS, so try the matching .m3u8 URL natively
    /// while preserving the original URL for compatibility fallback.
    private func nativePreferredURL(from original: URL) -> URL {
        let absolute = original.absoluteString
        if kind == .live && absolute.lowercased().hasSuffix(".ts") {
            let hls = String(absolute.dropLast(3)) + ".m3u8"
            return URL(string: hls) ?? original
        }
        return original
    }

    private var canShowTimeline: Bool {
        duration > 1 && (kind == .vod || isSeekable)
    }

    private var currentProgramme: EPGProgramme? {
        guard kind == .live, let epgChannelId, !epgChannelId.isEmpty else { return nil }
        return epg.nowPlaying(channelId: epgChannelId)
    }

    private var nextProgramme: EPGProgramme? {
        guard kind == .live, let epgChannelId, !epgChannelId.isEmpty else { return nil }
        return epg.upcoming(channelId: epgChannelId, limit: 1).first
    }

    private var upcomingProgrammes: [EPGProgramme] {
        guard kind == .live, let epgChannelId, !epgChannelId.isEmpty else { return [] }
        return epg.upcoming(channelId: epgChannelId, limit: 6)
    }

    private var isLiveFavorite: Bool {
        guard kind == .live,
              let sourceID = store.activeSourceID,
              let id = epgChannelId else { return false }
        return favorites.contains(sourceID: sourceID, kind: .live, id: id)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if episodeSwitchInProgress {
                ZStack {
                    Color.black
                    ProgressView("Loading episode…")
                        .tint(Theme.accent)
                        .foregroundStyle(.white)
                }
                .ignoresSafeArea()
            } else if let url = streamURL {
                playbackSurface(url: url)
                    .background(Color.black)
                    .ignoresSafeArea()
            } else {
                invalidURLView
            }

            // UIKit/AVPlayer/VLC surfaces can consume taps before SwiftUI's
            // parent gesture sees them. Keep a dedicated transparent hit area
            // above the video and below the controls so a tap always restores
            // the Back / playback controls in portrait or landscape.
            PlayerTapCatcher {
                showControlsFromTap()
            }
            .ignoresSafeArea()

            if controlsVisible {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .transaction { transaction in
            // Playback-time state changes should never animate the entire
            // full-screen hierarchy; that creates extra compositing work.
            transaction.animation = nil
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .onAppear {
            if currentEpisodeID == nil { currentEpisodeID = seriesContext?.initialEpisodeID }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                setLandscapePlayback(true)
            }
            scheduleControlsHide()
        }
        .task(id: epgChannelId) {
            guard kind == .live,
                  let epgChannelId,
                  let streamId = Int(epgChannelId),
                  let source = store.activeSource else { return }
            await epg.ensureProviderEPG(streamId: streamId, source: source)
        }
        .onChange(of: isPlaying) { playing in
            if kind == .live && playing {
                hasPlaybackStarted = true
            }
            if kind == .vod && !playing && duration > 0 {
                publishProgress(force: true)
            }
        }
        .onChange(of: currentTime) { value in
            guard kind == .vod else { return }
            restoreProgressIfNeeded()
            VODResumeStore.save(value, duration: duration, for: resumeID)

            if Date().timeIntervalSince(lastProgressPublishedAt) >= 10 {
                publishProgress(force: false)
            }
        }
        .onChange(of: playbackEndedToken) { _ in
            guard kind == .vod, !episodeSwitchInProgress else { return }
            currentTime = max(currentTime, duration)
            publishProgress(force: true, completedOverride: true)
            VODResumeStore.clear(resumeID)
            if autoPlayNext { playAdjacentEpisode(offset: 1) }
        }
        .onDisappear {
            controlsHideWorkItem?.cancel()
            if kind == .vod {
                publishProgress(force: true)
                VODResumeStore.save(currentTime, duration: duration, for: resumeID)
            }
            setLandscapePlayback(false)
        }
    }

    @ViewBuilder
    private func playbackSurface(url: URL) -> some View {
        #if canImport(MobileVLCKit)
        if useCompatibilityEngine {
            EmbeddedCompatibilityPlayer(
                url: url,
                kind: kind,
                isPlaying: $isPlaying,
                currentTime: $currentTime,
                duration: $duration,
                isSeekable: $isSeekable,
                requestedPosition: $requestedPosition,
                playbackCommand: playbackCommand,
                playbackRate: playbackRate,
                aspectFill: aspectFill,
                audioTracks: $audioTracks,
                subtitleTracks: $subtitleTracks,
                selectedAudioTrack: selectedAudioTrack,
                selectedSubtitleTrack: selectedSubtitleTrack,
                trackCommand: trackCommand,
                playbackEndedToken: $playbackEndedToken
            )
            .id("compatibility-\(url.absoluteString)")
        } else {
            NativePlayerSurface(
                url: tryOriginalNativeURL ? url : nativePreferredURL(from: url),
                kind: kind,
                isPlaying: $isPlaying,
                currentTime: $currentTime,
                duration: $duration,
                isSeekable: $isSeekable,
                requestedPosition: $requestedPosition,
                playbackCommand: playbackCommand,
                playbackRate: playbackRate,
                aspectFill: aspectFill,
                audioTracks: $audioTracks,
                subtitleTracks: $subtitleTracks,
                selectedAudioTrack: selectedAudioTrack,
                selectedSubtitleTrack: selectedSubtitleTrack,
                trackCommand: trackCommand,
                playbackEndedToken: $playbackEndedToken,
                onFailure: { message in
                    DispatchQueue.main.async {
                        nativeError = message
                        resetPlaybackStateForEngineSwitch()

                    // For Xtream/live URLs, don't jump directly from a guessed
                    // HLS variant to the compatibility engine. Give AVPlayer
                    // one more attempt with the provider's original URL so iOS
                    // can keep hardware-accelerated playback whenever possible.
                    if !tryOriginalNativeURL,
                       nativePreferredURL(from: url) != url {
                        tryOriginalNativeURL = true
                    } else {
                        useCompatibilityEngine = true
                    }
                    }
                }
            )
            .id("native-\(url.absoluteString)-\(tryOriginalNativeURL)")
        }
        #else
        NativePlayerSurface(
            url: nativePreferredURL(from: url),
            kind: kind,
            isPlaying: $isPlaying,
            currentTime: $currentTime,
            duration: $duration,
            isSeekable: $isSeekable,
            requestedPosition: $requestedPosition,
            playbackCommand: playbackCommand,
            playbackRate: playbackRate,
            aspectFill: aspectFill,
            audioTracks: $audioTracks,
            subtitleTracks: $subtitleTracks,
            selectedAudioTrack: selectedAudioTrack,
            selectedSubtitleTrack: selectedSubtitleTrack,
            trackCommand: trackCommand,
            playbackEndedToken: $playbackEndedToken,
            onFailure: { message in
                nativeError = message
            }
        )
        #endif
    }

    private var invalidURLView: some View {
        ZStack {
            Color.black
            VStack(spacing: 12) {
                Image(systemName: "play.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Invalid stream URL.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var controlsOverlay: some View {
        if kind == .live {
            liveMockupOverlay
        } else {
            vodControlsOverlay
        }
    }

    private var liveMockupOverlay: some View {
        GeometryReader { proxy in
            let guideWidth = max(330, min(proxy.size.width * 0.34, 520))
            let bottomHeight: CGFloat = 132

            ZStack(alignment: .topLeading) {
                // Back is always obvious whenever the player controls are visible.
                Button {
                    setLandscapePlayback(false)
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(.black.opacity(0.72), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .padding(.leading, 26)
                .padding(.top, 18)
                .zIndex(5)

                if let liveUtilityMessage {
                    Text(liveUtilityMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.80), in: Capsule())
                        .overlay(Capsule().stroke(liveAccent.opacity(0.45), lineWidth: 1))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                        .transition(.opacity)
                        .zIndex(6)
                }

                // Full provider EPG panel, visually matching the approved mockup.
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Live TV - EPG")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        HStack(spacing: 7) {
                            Image(systemName: "calendar")
                            Text("Guide")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(liveAccent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            if let currentProgramme {
                                guideRow(currentProgramme, isCurrent: true)
                            } else {
                                HStack {
                                    Text("No guide data")
                                        .font(.headline)
                                        .foregroundStyle(.white.opacity(0.7))
                                    Spacer()
                                }
                                .padding(18)
                            }

                            ForEach(upcomingProgrammes) { programme in
                                guideRow(programme, isCurrent: false)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                    }
                }
                .frame(width: guideWidth, height: max(260, proxy.size.height - bottomHeight - 16))
                .background(.black.opacity(0.90), in: RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: liveAccent.opacity(0.18), radius: 18)
                .padding(.top, 14)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)

                // Bottom program information and mockup-style control strip.
                VStack(spacing: 0) {
                    Spacer()

                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 9) {
                                Text("LIVE")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(liveAccent, in: Capsule())
                            }

                            if let currentProgramme {
                                Text(currentProgramme.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.94))
                                    .lineLimit(1)
                                if let desc = currentProgramme.desc, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.62))
                                        .lineLimit(1)
                                }
                                Text(timeRange(currentProgramme))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.72))
                            } else {
                                Text("Live stream")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.66))
                            }
                        }
                        .frame(maxWidth: 360, alignment: .leading)

                        if let currentProgramme {
                            PlayerEPGProgressBar(start: currentProgramme.start, stop: currentProgramme.stop)
                                .frame(maxWidth: 300)
                                .padding(.bottom, 6)
                        }

                        Spacer(minLength: 10)
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 10)

                    HStack(spacing: 14) {
                        playerActionButton(
                            title: "Favorite",
                            systemImage: isLiveFavorite ? "heart.fill" : "heart",
                            highlighted: isLiveFavorite
                        ) {
                            toggleLiveFavorite()
                        }

                        Spacer(minLength: 4)

                        roundTransportButton(systemImage: "gobackward.10", label: "-10s") {
                            seekLiveBy(seconds: -10)
                        }

                        roundTransportButton(
                            systemImage: isPlaying ? "pause.fill" : "play.fill",
                            label: isPlaying ? "Pause" : "Resume",
                            emphasized: true
                        ) {
                            playbackCommand += 1
                            scheduleControlsHide()
                        }

                        roundTransportButton(systemImage: "goforward.10", label: "+10s") {
                            seekLiveBy(seconds: 10)
                        }

                        playerActionButton(title: "LIVE", systemImage: "dot.radiowaves.left.and.right") {
                            jumpToLiveEdge()
                        }

                        Spacer(minLength: 18)

                        playerActionButton(title: "Channels", systemImage: "list.bullet") {
                            setLandscapePlayback(false)
                            presentationMode.wrappedValue.dismiss()
                        }
                        playerActionButton(title: "Audio", systemImage: "headphones") {
                            showUtilityMessage("Audio options depend on the selected stream.")
                        }
                        playerActionButton(title: "Subtitles", systemImage: "captions.bubble") {
                            showUtilityMessage("Subtitle options depend on the selected stream.")
                        }
                        playerActionButton(title: "More", systemImage: "ellipsis") {
                            showUtilityMessage("More playback options are available when supported by the stream.")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.92))
                }
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.20), .black.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                )
            }
        }
    }

    private func guideRow(_ programme: EPGProgramme, isCurrent: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(shortTime(programme.start))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 74, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(programme.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if isCurrent {
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(liveAccent, in: RoundedRectangle(cornerRadius: 5))
                    }
                }
                if let desc = programme.desc, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.60))
                        .lineLimit(2)
                }
                if isCurrent {
                    PlayerEPGProgressBar(start: programme.start, stop: programme.stop)
                        .padding(.top, 3)
                }
            }

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.65))
                .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(isCurrent ? liveAccent.opacity(0.13) : Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(isCurrent ? liveAccent : Color.white.opacity(0.08), lineWidth: isCurrent ? 2 : 1)
        )
        .shadow(color: isCurrent ? liveAccent.opacity(0.26) : .clear, radius: 12)
    }

    private var vodControlsOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { setLandscapePlayback(false); presentationMode.wrappedValue.dismiss() } label: {
                    Image(systemName: "chevron.left").font(.headline.weight(.bold)).frame(width: 44, height: 44).background(.black.opacity(0.65), in: Circle())
                }.buttonStyle(.plain).accessibilityLabel("Back")
                Spacer()
                if seriesContext != nil {
                    Button { showEpisodeInfo.toggle() } label: { Label("Episode Info", systemImage: "info.circle") }.buttonStyle(.bordered)
                }
            }.padding(.horizontal, 18).padding(.top, 10).foregroundStyle(.white)

            Spacer()

            if showEpisodeInfo, let context = seriesContext, let episode = currentSeriesEpisode {
                VStack(alignment: .leading, spacing: 5) {
                    Text(context.seriesTitle).font(.headline)
                    Text("Season \(episode.season) • Episode \(episode.episodeNum)").font(.caption).foregroundStyle(Theme.accent)
                    if let plot = context.plot, !plot.isEmpty { Text(plot).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
                }.padding(14).frame(maxWidth: 520, alignment: .leading).background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 14))
            }

            VStack(spacing: 12) {
                if canShowTimeline {
                    HStack(spacing: 10) {
                        Text(formatTime(currentTime)).font(.caption.monospacedDigit())
                        Slider(value: Binding(get: { min(max(currentTime,0),max(duration,1)) }, set: { currentTime=$0 }), in: 0...max(duration,1), onEditingChanged: { editing in
                            isScrubbing=editing; controlsHideWorkItem?.cancel(); if !editing, duration > 0 { requestedPosition=min(max(currentTime/duration,0),1); scheduleControlsHide() }
                        }).tint(Theme.accent)
                        Text(formatTime(duration)).font(.caption.monospacedDigit())
                    }
                }

                HStack(spacing: 22) {
                    Button { seekVODBy(seconds: -10) } label: { Image(systemName: "gobackward.10").font(.title2) }
                    Button { playbackCommand += 1 } label: { Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.system(size: 30, weight: .bold)).frame(width: 58,height:58).background(Theme.accent.opacity(0.9),in:Circle()) }
                    Button { seekVODBy(seconds: 10) } label: { Image(systemName: "goforward.10").font(.title2) }
                }.buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Pause" : "Resume")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Menu {
                            ForEach([0.5,0.75,1.0,1.25,1.5,2.0], id: \.self) { rate in Button("\(rate, specifier: "%g")×") { playbackRate=Float(rate) } }
                        } label: { playerOptionLabel("Playback Speed", "speedometer") }
                        Button { aspectFill.toggle() } label: { playerOptionLabel(aspectFill ? "Aspect Fill" : "Aspect Fit", "rectangle.arrowtriangle.2.outward") }
                        Menu {
                            if audioTracks.isEmpty { Text("No alternate audio tracks") }
                            ForEach(audioTracks) { track in Button(track.name) { selectedAudioTrack=track.id; trackCommand += 1 } }
                        } label: { playerOptionLabel("Audio Language", "waveform") }
                        Menu {
                            Button("Off") { selectedSubtitleTrack = -1; trackCommand += 1 }
                            if subtitleTracks.isEmpty { Text("No subtitle tracks") }
                            ForEach(subtitleTracks) { track in Button(track.name) { selectedSubtitleTrack=track.id; trackCommand += 1 } }
                        } label: { playerOptionLabel("Subtitles / CC", "captions.bubble") }
                        Button { restartVOD() } label: { playerOptionLabel("Restart", "arrow.counterclockwise") }
                    }
                }

                if let context = seriesContext {
                    HStack(spacing: 10) {
                        Button { playAdjacentEpisode(offset: -1) } label: { Label("Previous Episode", systemImage: "backward.end.fill") }.disabled(episodeSwitchInProgress || !hasAdjacentEpisode(-1))
                        Menu {
                            ForEach(Array(Set(context.episodes.map(\.season))).sorted(), id: \.self) { season in
                                Menu("Season \(season)") { ForEach(context.episodes.filter{$0.season==season}) { ep in Button("E\(ep.episodeNum)  \(ep.title)") { switchEpisode(to: ep) } } }
                            }
                        } label: { Label("Season / Episode", systemImage: "list.bullet.rectangle") }
                        Button { playAdjacentEpisode(offset: 1) } label: { Label("Next Episode", systemImage: "forward.end.fill") }.disabled(episodeSwitchInProgress || !hasAdjacentEpisode(1))
                        Toggle("Auto-play Next", isOn: $autoPlayNext).toggleStyle(.button)
                    }.font(.caption.weight(.semibold))
                }
            }.foregroundStyle(.white).padding(.horizontal,22).padding(.bottom,18)
        }
    }

    private func playerOptionLabel(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon).font(.caption.weight(.semibold)).padding(.horizontal,12).padding(.vertical,9).background(Color.white.opacity(0.08), in: Capsule())
    }

    private func seekVODBy(seconds: Double) {
        guard duration > 0 else { return }; let target=min(max(currentTime+seconds,0),duration); currentTime=target; requestedPosition=target/duration
    }
    private func restartVOD() {
        VODResumeStore.clear(resumeID)
        currentTime = 0
        requestedPosition = 0
        didRestoreResume = true
        publishProgress(force: true, completedOverride: false)
    }
    private func orderedEpisodes() -> [Episode] { seriesContext?.episodes.sorted { ($0.season,$0.episodeNum) < ($1.season,$1.episodeNum) } ?? [] }
    private func hasAdjacentEpisode(_ offset: Int) -> Bool {
        let list=orderedEpisodes(); guard let id=currentSeriesEpisode?.id, let i=list.firstIndex(where:{$0.id==id}) else{return false}; return list.indices.contains(i+offset)
    }
    private func playAdjacentEpisode(offset: Int) {
        guard !episodeSwitchInProgress else { return }
        let list = orderedEpisodes()
        guard let id = currentSeriesEpisode?.id,
              let index = list.firstIndex(where: { $0.id == id }),
              list.indices.contains(index + offset) else { return }
        switchEpisode(to: list[index + offset])
    }

    private func switchEpisode(to episode: Episode) {
        guard !episodeSwitchInProgress, episode.id != currentSeriesEpisode?.id else { return }

        // Remove the current player surface before installing another episode.
        // This avoids re-targeting AVPlayer/VLC while decoder callbacks from the
        // previous episode are still in flight.
        let previousResumeID = resumeID
        publishProgress(force: true)
        VODResumeStore.save(currentTime, duration: duration, for: previousResumeID)
        episodeSwitchInProgress = true
        didRestoreResume = false
        audioTracks = []
        subtitleTracks = []
        selectedAudioTrack = nil
        selectedSubtitleTrack = nil
        resetPlaybackStateForEngineSwitch()
        useCompatibilityEngine = false
        tryOriginalNativeURL = false
        nativeError = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            currentEpisodeID = episode.id
            didRestoreResume = false
            lastProgressPublishedAt = .distantPast
            episodeSwitchInProgress = false
            scheduleControlsHide()
        }
    }

    private func restoreProgressIfNeeded() {
        guard !didRestoreResume,
              kind == .vod,
              duration > 30,
              let sourceID = store.activeSourceID,
              let contentID = progressContentID else { return }

        didRestoreResume = true

        if let synced = playbackProgress.records.first(where: {
            $0.sourceID == sourceID &&
            $0.contentKind == progressContentKind &&
            $0.contentID == contentID &&
            !$0.completed
        }), synced.positionSeconds > 10,
           synced.durationSeconds > 0,
           synced.positionSeconds < synced.durationSeconds * 0.95 {
            requestedPosition = min(max(synced.positionSeconds / max(duration, synced.durationSeconds), 0), 0.94)
            return
        }

        let legacy = VODResumeStore.position(for: resumeID)
        if legacy > 10, legacy < duration * 0.95 {
            requestedPosition = legacy / duration
        }
    }

    private func publishProgress(
        force: Bool,
        completedOverride: Bool? = nil
    ) {
        guard kind == .vod,
              let sourceID = store.activeSourceID,
              let contentID = progressContentID,
              duration.isFinite,
              duration > 0,
              currentTime.isFinite else { return }

        if !force && Date().timeIntervalSince(lastProgressPublishedAt) < 10 {
            return
        }

        let completionRatio = min(max(currentTime / duration, 0), 1)
        let completed = completedOverride ?? (completionRatio >= 0.95)
        let now = Date()

        let record = playbackProgress.record(
            sourceID: sourceID,
            contentKind: progressContentKind,
            contentID: contentID,
            title: effectiveTitle,
            seriesID: seriesContext?.seriesID,
            positionSeconds: completed ? duration : currentTime,
            durationSeconds: duration,
            completed: completed,
            updatedAt: now
        )

        ActivityStore.shared.record(
            ActivityEntry(
                sourceID: sourceID,
                contentKind: progressContentKind.rawValue,
                contentID: contentID,
                title: effectiveTitle,
                deviceName: UIDevice.current.name,
                updatedAt: now
            )
        )

        SyncEngine.shared.enqueueProgress(record)
        lastProgressPublishedAt = now

        Task {
            await SyncEngine.shared.pushPending()
        }
    }

    private func playerActionButton(
        title: String,
        systemImage: String,
        highlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(highlighted ? liveAccent : .white)
            .frame(minWidth: 70, minHeight: 60)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(highlighted ? liveAccent : Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func roundTransportButton(
        systemImage: String,
        label: String,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: emphasized ? 26 : 20, weight: .bold))
                    .frame(width: emphasized ? 62 : 50, height: emphasized ? 62 : 50)
                    .background(.black.opacity(0.55), in: Circle())
                    .overlay(
                        Circle().stroke(emphasized ? liveAccent : Color.white.opacity(0.18), lineWidth: emphasized ? 2 : 1)
                    )
                    .shadow(color: emphasized ? liveAccent.opacity(0.35) : .clear, radius: 12)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func toggleLiveFavorite() {
        guard let sourceID = store.activeSourceID, let id = epgChannelId else { return }
        favorites.toggle(sourceID: sourceID, kind: .live, id: id)
    }

    private func seekLiveBy(seconds: Double) {
        guard isSeekable, duration > 0 else { return }
        let target = min(max(currentTime + seconds, 0), duration)
        currentTime = target
        requestedPosition = min(max(target / duration, 0), 1)
    }

    private func jumpToLiveEdge() {
        guard isSeekable, duration > 0 else { return }
        currentTime = duration
        requestedPosition = 1
    }

    private func showUtilityMessage(_ message: String) {
        liveUtilityMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if liveUtilityMessage == message {
                withAnimation(.easeOut(duration: 0.18)) {
                    liveUtilityMessage = nil
                }
            }
        }
    }

    private func timeRange(_ programme: EPGProgramme) -> String {
        "\(shortTime(programme.start)) - \(shortTime(programme.stop))"
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func resetPlaybackStateForEngineSwitch() {
        currentTime = 0
        duration = 0
        isSeekable = false
        requestedPosition = nil
        isPlaying = false
    }

    private func showControlsFromTap() {
        controlsHideWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) {
            controlsVisible = true
        }
        scheduleControlsHide()
    }

    private func scheduleControlsHide() {
        controlsHideWorkItem?.cancel()
        guard !isScrubbing else { return }
        let work = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.25)) {
                controlsVisible = false
            }
        }
        controlsHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func setLandscapePlayback(_ landscape: Bool) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }

        if #available(iOS 16.0, *) {
            let mask: UIInterfaceOrientationMask = landscape ? .landscape : .portrait
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
            scene.requestGeometryUpdate(preferences)
            scene.windows.first(where: { $0.isKeyWindow })?
                .rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

private struct PlayerEPGProgressBar: View {
    let start: Date
    let stop: Date

    private var progress: Double {
        let total = stop.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        return min(max(elapsed / total, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(Theme.accent)
                    .frame(width: max(8, geo.size.width * progress))
            }
        }
        .frame(height: 5)
    }
}

private struct PlayerTapCatcher: View {
    let action: () -> Void

    var body: some View {
        Color.white.opacity(0.001)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityHidden(true)
    }
}

// MARK: - Native AVPlayer engine

/// AVPlayer-backed video surface with no Apple player chrome. GhostStream's
/// own controls remain on top, while AVPlayer supplies hardware-accelerated
/// playback for HLS and other formats supported by iOS.
private struct NativePlayerSurface: UIViewRepresentable {
    let url: URL
    let kind: PlayerContentKind
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isSeekable: Bool
    @Binding var requestedPosition: Double?
    let playbackCommand: Int
    let playbackRate: Float
    let aspectFill: Bool
    @Binding var audioTracks: [PlayerMediaTrack]
    @Binding var subtitleTracks: [PlayerMediaTrack]
    let selectedAudioTrack: Int?
    let selectedSubtitleTrack: Int?
    let trackCommand: Int
    @Binding var playbackEndedToken: Int
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView(frame: .zero)
        view.backgroundColor = .black
        context.coordinator.attach(to: view, url: url)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        context.coordinator.parent = self

        // Never drive AVPlayer or write SwiftUI bindings while SwiftUI is in
        // the middle of updateUIView. Doing so can trigger
        // "Publishing changes from within view updates" and can stall the
        // main thread during rotation. Defer the player work one run-loop turn.
        let coordinator = context.coordinator
        let updateURL = url
        let command = playbackCommand
        let seekPosition = requestedPosition
        DispatchQueue.main.async {
            coordinator.update(url: updateURL, view: uiView)
            coordinator.handlePlaybackCommand(command)
            coordinator.applyPlaybackRate()
            coordinator.handleTrackCommand(self.trackCommand)
            if let position = seekPosition {
                coordinator.seek(to: position)
                coordinator.parent.requestedPosition = nil
            }
        }
    }

    static func dismantleUIView(_ uiView: PlayerLayerView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject {
        var parent: NativePlayerSurface

        private let player = AVPlayer()
        private var currentURL: URL?
        private var itemStatusObservation: NSKeyValueObservation?
        private var timeControlObservation: NSKeyValueObservation?
        private var timeObserver: Any?
        private var failedToEndObserver: NSObjectProtocol?
        private var didEndObserver: NSObjectProtocol?
        private var lastPlaybackCommand = 0
        private var lastTrackCommand = 0
        private var failureDelivered = false
        private var readinessWorkItem: DispatchWorkItem?

        init(parent: NativePlayerSurface) {
            self.parent = parent
            super.init()
        }

        func attach(to view: PlayerLayerView, url: URL) {
            view.clipsToBounds = true
            view.playerLayer.player = player
            // Live broadcasts keep the full frame visible so scoreboards and
            // channel graphics at the edges are never cropped. VOD keeps the
            // immersive edge-to-edge fill behavior.
            view.playerLayer.videoGravity = parent.kind == .live ? .resizeAspect : .resizeAspectFill
            if parent.kind == .vod && !parent.aspectFill { view.playerLayer.videoGravity = .resizeAspect }
            play(url: url)
        }

        func update(url: URL, view: PlayerLayerView) {
            // Do not re-attach AVPlayer to the layer on every SwiftUI update.
            // Rotation can trigger many updateUIView calls and repeatedly
            // touching the render surface can cause dropped frames.
            if view.playerLayer.player !== player {
                view.playerLayer.player = player
            }
            view.playerLayer.videoGravity = parent.kind == .live ? .resizeAspect : .resizeAspectFill
            if parent.kind == .vod && !parent.aspectFill { view.playerLayer.videoGravity = .resizeAspect }
            guard currentURL != url else { return }
            play(url: url)
        }

        private func play(url: URL) {
            cleanupItemObservers()
            currentURL = url
            failureDelivered = false

            let asset = AVURLAsset(url: url)
            let item = AVPlayerItem(asset: asset)

            // Give iOS enough runway to absorb jitter from IPTV servers without
            // building an excessively long delay. VOD gets a little more buffer
            // because latency is less important there.
            item.preferredForwardBufferDuration = (parent.kind == .live) ? 6 : 10
            item.preferredMaximumResolution = CGSize(width: 1920, height: 1080)
            // Avoid providers selecting unnecessarily huge variants that can
            // overwhelm older iPhones during full-screen landscape playback.
            item.preferredPeakBitRate = (parent.kind == .live) ? 8_000_000 : 12_000_000
            if #available(iOS 10.0, *) {
                item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            }

            observe(item: item)
            player.replaceCurrentItem(with: item)
            player.automaticallyWaitsToMinimizeStalling = true
            player.actionAtItemEnd = .pause
            player.playImmediately(atRate: 1.0)
            publishState()

            // Some malformed/unsupported IPTV streams never transition to
            // `.failed`; if native playback is still not ready after the grace
            // period, allow GhostStream to select the compatibility engine.
            let work = DispatchWorkItem { [weak self, weak item] in
                guard let self = self, let item = item else { return }
                if item.status != .readyToPlay {
                    self.failNative("Native playback could not prepare this stream.")
                }
            }
            readinessWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: work)
        }

        private func observe(item: AVPlayerItem) {
            itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
                guard let self = self else { return }
                switch observed.status {
                case .readyToPlay:
                    self.readinessWorkItem?.cancel()
                    self.publishMediaTracks(item: observed)
                    self.applyPlaybackRate()
                    self.publishState()
                case .failed:
                    let message = observed.error?.localizedDescription ?? "Native playback could not open this stream."
                    self.failNative(message)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }

            timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
                self?.publishState()
            }

            didEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.parent.playbackEndedToken += 1
            }

            failedToEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] note in
                let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                self?.failNative(error?.localizedDescription ?? "Native playback failed.")
            }

            let interval = CMTime(seconds: 1.0, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
                self?.publishState()
            }
        }

        func handlePlaybackCommand(_ command: Int) {
            guard command != lastPlaybackCommand else { return }
            lastPlaybackCommand = command
            if player.timeControlStatus == .playing {
                player.pause()
            } else {
                player.play()
            }
            publishState()
        }

        func applyPlaybackRate() {
            guard parent.kind == .vod, player.timeControlStatus == .playing else { return }
            if abs(player.rate - parent.playbackRate) > 0.01 { player.rate = parent.playbackRate }
        }

        func handleTrackCommand(_ command: Int) {
            guard command != lastTrackCommand, let item = player.currentItem else { return }
            lastTrackCommand = command

            // iOS 16 deprecated the synchronous mediaSelectionGroup API.
            // Load the real audio/subtitle groups asynchronously, then apply the
            // user's current selections to this exact player item.
            Task { @MainActor [weak self, weak item] in
                guard let self, let item, self.player.currentItem === item else { return }

                if let group = try? await item.asset.loadMediaSelectionGroup(for: .audible),
                   let index = self.parent.selectedAudioTrack,
                   group.options.indices.contains(index) {
                    item.select(group.options[index], in: group)
                }

                if let group = try? await item.asset.loadMediaSelectionGroup(for: .legible) {
                    if self.parent.selectedSubtitleTrack == -1 {
                        item.select(nil, in: group)
                    } else if let index = self.parent.selectedSubtitleTrack,
                              group.options.indices.contains(index) {
                        item.select(group.options[index], in: group)
                    }
                }
            }
        }

        private func publishMediaTracks(item: AVPlayerItem) {
            Task { @MainActor [weak self, weak item] in
                guard let self, let item, self.player.currentItem === item else { return }

                let audioGroup = try? await item.asset.loadMediaSelectionGroup(for: .audible)
                let subtitleGroup = try? await item.asset.loadMediaSelectionGroup(for: .legible)

                guard self.player.currentItem === item else { return }
                self.parent.audioTracks = audioGroup?.options.enumerated().map {
                    PlayerMediaTrack(id: $0.offset, name: $0.element.displayName)
                } ?? []
                self.parent.subtitleTracks = subtitleGroup?.options.enumerated().map {
                    PlayerMediaTrack(id: $0.offset, name: $0.element.displayName)
                } ?? []
            }
        }

        func seek(to normalizedPosition: Double) {
            guard let item = player.currentItem else { return }
            let targetPosition = min(max(normalizedPosition, 0), 1)

            let itemDuration = CMTimeGetSeconds(item.duration)
            if itemDuration.isFinite && itemDuration > 0 {
                let time = CMTime(seconds: itemDuration * targetPosition, preferredTimescale: 600)
                player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
                return
            }

            // DVR/live streams usually expose a moving seekable time range
            // instead of a finite item duration.
            if let range = item.seekableTimeRanges.last?.timeRangeValue {
                let start = CMTimeGetSeconds(range.start)
                let length = CMTimeGetSeconds(range.duration)
                if start.isFinite && length.isFinite && length > 0 {
                    let time = CMTime(seconds: start + (length * targetPosition), preferredTimescale: 600)
                    player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
                }
            }
        }

        private func publishState() {
            guard let item = player.currentItem else { return }

            let playing = player.timeControlStatus == .playing || player.rate > 0
            let current = max(CMTimeGetSeconds(player.currentTime()), 0)

            let finiteDuration = CMTimeGetSeconds(item.duration)
            var total: Double = 0
            var elapsed = current
            var seekable = false

            if finiteDuration.isFinite && finiteDuration > 0 {
                total = finiteDuration
                seekable = true
            } else if let range = item.seekableTimeRanges.last?.timeRangeValue {
                let start = CMTimeGetSeconds(range.start)
                let length = CMTimeGetSeconds(range.duration)
                if start.isFinite && length.isFinite && length > 1 {
                    total = length
                    elapsed = min(max(current - start, 0), length)
                    seekable = true
                }
            }

            DispatchQueue.main.async {
                self.parent.isPlaying = playing
                self.parent.isSeekable = seekable
                self.parent.currentTime = elapsed.isFinite ? elapsed : 0
                self.parent.duration = total.isFinite ? total : 0
            }
        }

        private func failNative(_ message: String) {
            guard !failureDelivered else { return }
            failureDelivered = true
            readinessWorkItem?.cancel()
            player.pause()
            DispatchQueue.main.async {
                self.parent.onFailure(message)
            }
        }

        func stop() {
            readinessWorkItem?.cancel()
            player.pause()
            player.replaceCurrentItem(with: nil)
            cleanupItemObservers()
            currentURL = nil
        }

        private func cleanupItemObservers() {
            readinessWorkItem?.cancel()
            readinessWorkItem = nil
            itemStatusObservation = nil
            timeControlObservation = nil

            if let observer = didEndObserver { NotificationCenter.default.removeObserver(observer); didEndObserver = nil }
            if let observer = failedToEndObserver {
                NotificationCenter.default.removeObserver(observer)
                failedToEndObserver = nil
            }
            if let observer = timeObserver {
                player.removeTimeObserver(observer)
                timeObserver = nil
            }
        }
    }
}

private final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

#if canImport(MobileVLCKit)
// MARK: - Embedded compatibility engine

/// Compatibility player used only if AVPlayer cannot open the stream.
/// No third-party branding is exposed in the GhostStream interface.
private struct EmbeddedCompatibilityPlayer: UIViewRepresentable {
    let url: URL
    let kind: PlayerContentKind
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isSeekable: Bool
    @Binding var requestedPosition: Double?
    let playbackCommand: Int
    let playbackRate: Float
    let aspectFill: Bool
    @Binding var audioTracks: [PlayerMediaTrack]
    @Binding var subtitleTracks: [PlayerMediaTrack]
    let selectedAudioTrack: Int?
    let selectedSubtitleTrack: Int?
    let trackCommand: Int
    @Binding var playbackEndedToken: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        view.clipsToBounds = true
        view.contentMode = kind == .live ? .scaleAspectFit : .scaleAspectFill
        if kind == .vod && !aspectFill { view.contentMode = .scaleAspectFit }
        context.coordinator.attach(to: view, url: url)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        uiView.contentMode = kind == .live ? .scaleAspectFit : .scaleAspectFill
        if kind == .vod && !aspectFill { uiView.contentMode = .scaleAspectFit }

        // Keep MobileVLCKit work outside SwiftUI's representable update pass.
        // Rotation can cause a burst of updateUIView calls; synchronous decoder
        // work here can block gestures and trip the watchdog.
        let coordinator = context.coordinator
        let updateURL = url
        let command = playbackCommand
        let seekPosition = requestedPosition
        DispatchQueue.main.async {
            coordinator.update(url: updateURL, drawable: uiView)
            coordinator.handlePlaybackCommand(command)
            coordinator.applyPlaybackOptions(trackCommand: self.trackCommand)
            if let position = seekPosition {
                coordinator.seek(to: Float(position))
                coordinator.parent.requestedPosition = nil
            }
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        var parent: EmbeddedCompatibilityPlayer
        private let mediaPlayer = VLCMediaPlayer()
        private var currentURL: URL?
        private var lastPlaybackCommand = 0
        private var lastTrackCommand = 0
        private var lastStatePublishTime: CFTimeInterval = 0
        private weak var currentDrawable: UIView?
        private var isStopped = false

        init(parent: EmbeddedCompatibilityPlayer) {
            self.parent = parent
            super.init()
        }

        func attach(to view: UIView, url: URL) {
            isStopped = false
            mediaPlayer.delegate = self
            currentDrawable = view
            mediaPlayer.drawable = view
            play(url: url)
        }

        func update(url: URL, drawable: UIView) {
            guard !isStopped else { return }
            // URL changes are handled by replacing the whole representable.
            // Never stop and retarget an active VLCMediaPlayer in-place.
            guard currentURL == url else { return }
            if currentDrawable !== drawable {
                currentDrawable = drawable
                mediaPlayer.drawable = drawable
            }
        }

        private func play(url: URL) {
            guard !isStopped else { return }
            currentURL = url

            let media = VLCMedia(url: url)
            media.addOptions([
                // IPTV providers can have bursty delivery. A larger cache is
                // noticeably smoother on iPhone than the previous 1-second
                // setting while still keeping live latency reasonable.
                "network-caching": 3500,
                "live-caching": 3500,
                "file-caching": 1500,
                "http-reconnect": true,
                "clock-jitter": 0
            ])
            mediaPlayer.media = media
            mediaPlayer.play()
            publishState()
        }

        func handlePlaybackCommand(_ command: Int) {
            guard !isStopped, command != lastPlaybackCommand else { return }
            lastPlaybackCommand = command
            if mediaPlayer.isPlaying {
                mediaPlayer.pause()
            } else {
                mediaPlayer.play()
            }
            publishState()
        }

        func seek(to position: Float) {
            guard !isStopped, mediaPlayer.isSeekable else { return }
            mediaPlayer.position = min(max(position, 0), 1)
            publishState()
        }

        func mediaPlayerStateChanged(_ aNotification: Notification) {
            guard !isStopped else { return }
            publishMediaTracks()
            if mediaPlayer.state == .ended { parent.playbackEndedToken += 1 }
            publishState()
        }

        func applyPlaybackOptions(trackCommand: Int) {
            guard !isStopped else { return }
            if parent.kind == .vod, mediaPlayer.isPlaying { mediaPlayer.rate = parent.playbackRate }
            guard trackCommand != lastTrackCommand else { return }
            lastTrackCommand = trackCommand
            if let id = parent.selectedAudioTrack { mediaPlayer.currentAudioTrackIndex = Int32(id) }
            if let id = parent.selectedSubtitleTrack { mediaPlayer.currentVideoSubTitleIndex = Int32(id) }
        }

        private func publishMediaTracks() {
            guard !isStopped else { return }
            let audioNames = mediaPlayer.audioTrackNames as? [String] ?? []
            let audioIDs = mediaPlayer.audioTrackIndexes as? [NSNumber] ?? []
            let subNames = mediaPlayer.videoSubTitlesNames as? [String] ?? []
            let subIDs = mediaPlayer.videoSubTitlesIndexes as? [NSNumber] ?? []
            let audio = zip(audioIDs, audioNames).map { PlayerMediaTrack(id: $0.0.intValue, name: $0.1) }
            let subs = zip(subIDs, subNames).filter { $0.0.intValue >= 0 }.map { PlayerMediaTrack(id: $0.0.intValue, name: $0.1) }
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isStopped else { return }
                self.parent.audioTracks = audio
                self.parent.subtitleTracks = subs
            }
        }

        func mediaPlayerTimeChanged(_ aNotification: Notification) {
            guard !isStopped else { return }
            // MobileVLCKit can fire this callback many times per second. Updating
            // SwiftUI on every callback causes avoidable main-thread work and can
            // make video appear choppy, so refresh controls at ~4 Hz instead.
            let now = CACurrentMediaTime()
            guard now - lastStatePublishTime >= 0.5 else { return }
            lastStatePublishTime = now
            publishState()
        }

        private func publishState() {
            guard !isStopped else { return }
            let playing = mediaPlayer.isPlaying
            let seekable = mediaPlayer.isSeekable
            let elapsedMS = mediaPlayer.time.intValue
            let elapsed = max(Double(elapsedMS) / 1000.0, 0)

            var total: Double = 0
            let position = Double(mediaPlayer.position)
            if position > 0.0001 && position <= 1.0 {
                total = elapsed / position
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isStopped else { return }
                self.parent.isPlaying = playing
                self.parent.isSeekable = seekable
                self.parent.currentTime = elapsed
                self.parent.duration = (total.isFinite && total > 0) ? total : 0
            }
        }

        func stop() {
            guard !isStopped else { return }
            // Mark stopped before touching VLC so queued delegate callbacks
            // cannot publish state into a player that SwiftUI has removed.
            isStopped = true
            mediaPlayer.delegate = nil
            mediaPlayer.drawable = nil
            currentDrawable = nil
            mediaPlayer.stop()
            currentURL = nil
        }
    }
}
#endif
