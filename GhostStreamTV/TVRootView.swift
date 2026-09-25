import SwiftUI
import AVKit
import AVFoundation
import UIKit

#if canImport(TVVLCKit)
import TVVLCKit
#endif

private enum TVTheme {
    // APK-inspired black + purple visual system.
    static let accent = Color(red: 124/255, green: 92/255, blue: 1.0)
    static let accentBright = Color(red: 160/255, green: 128/255, blue: 1.0)
    static let background = Color(red: 11/255, green: 11/255, blue: 15/255)
    static let background2 = Color(red: 18/255, green: 12/255, blue: 28/255)
    static let card = Color(red: 17/255, green: 17/255, blue: 22/255)
    static let card2 = Color(red: 28/255, green: 24/255, blue: 44/255)
    static let chip = Color(red: 20/255, green: 20/255, blue: 28/255)
    static let muted = Color.white.opacity(0.58)
    static let border = accent.opacity(0.34)
    static let cardGradient = LinearGradient(
        colors: [Color(red: 27/255, green: 22/255, blue: 42/255), Color(red: 15/255, green: 15/255, blue: 20/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let heroGlow = LinearGradient(
        colors: [accent.opacity(0.22), accentBright.opacity(0.08), .clear],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}

/// Removes the default gray tvOS card chrome while preserving a tactile press state.
private struct TVGhostFocusStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

/// Cyan GhostStream focus treatment for Apple TV Remote navigation.
private struct TVGhostFocusModifier: ViewModifier {
    @Environment(\.isFocused) private var isFocused
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isFocused ? TVTheme.accent.opacity(0.90) : Color.clear, lineWidth: isFocused ? 2 : 0)
            )
            .shadow(color: TVTheme.accent.opacity(isFocused ? 0.22 : 0), radius: isFocused ? 12 : 0)
            .animation(.easeOut(duration: 0.12), value: isFocused)
    }
}

private struct TVPosterFocusModifier: ViewModifier {
    @Environment(\.isFocused) private var isFocused
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(isFocused ? 1.04 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isFocused ? TVTheme.accentBright : Color.clear, lineWidth: isFocused ? 3 : 0)
            )
            .shadow(color: TVTheme.accent.opacity(isFocused ? 0.28 : 0), radius: isFocused ? 16 : 0)
            .animation(.easeOut(duration: 0.12), value: isFocused)
    }
}

private extension View {
    func tvGhostFocus(cornerRadius: CGFloat = 18) -> some View {
        modifier(TVGhostFocusModifier(cornerRadius: cornerRadius))
    }

    func tvPosterFocus(cornerRadius: CGFloat = 18) -> some View {
        modifier(TVPosterFocusModifier(cornerRadius: cornerRadius))
    }
}

private enum TVMediaLayout {
    static let horizontalInset: CGFloat = 72
    static let liveCardWidth: CGFloat = 300
    static let liveArtworkHeight: CGFloat = 169
    static let posterWidth: CGFloat = 220
    static let posterHeight: CGFloat = 330
    static let gridSpacing: CGFloat = 34

    static func liveGridColumns(for width: CGFloat) -> [GridItem] {
        let usable = max(width - (horizontalInset * 2), liveCardWidth)
        let raw = Int((usable + gridSpacing) / (liveCardWidth + gridSpacing))
        let count = max(3, min(5, raw))
        return Array(
            repeating: GridItem(.fixed(liveCardWidth), spacing: gridSpacing, alignment: .top),
            count: count
        )
    }

    static func posterGridColumns(for width: CGFloat) -> [GridItem] {
        let usable = max(width - (horizontalInset * 2), posterWidth)
        let raw = Int((usable + gridSpacing) / (posterWidth + gridSpacing))
        let count = max(4, min(6, raw))
        return Array(
            repeating: GridItem(.fixed(posterWidth), spacing: gridSpacing, alignment: .top),
            count: count
        )
    }
}

private enum TVDisplayFormatter {
    static func cleanTitle(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["USA |", "US |", "U.S.A. |", "CANADA |", "CA |", "UK |", "U.K. |"]
        for prefix in prefixes where text.uppercased().hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }
        return text.replacingOccurrences(of: "  ", with: " ")
    }

    static func cleanCategory(_ value: String) -> String {
        let cleaned = cleanTitle(value)
        return cleaned
            .replacingOccurrences(of: "|", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }
}

private struct TVGhostInputField: ViewModifier {
    @Environment(\.isFocused) private var isFocused

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(TVTheme.cardGradient)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isFocused ? TVTheme.accent : Color.white.opacity(0.14), lineWidth: isFocused ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: TVTheme.accent.opacity(isFocused ? 0.18 : 0), radius: 14)
    }
}

private extension View {
    func tvInputStyle() -> some View {
        modifier(TVGhostInputField())
    }
}

struct TVRootView: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var epg: EPGService
    @State private var showSources = false
    @State private var showPairing = false

    var body: some View {
        NavigationStack {
            ZStack {
                TVBackground()
                if store.activeSource == nil {
                    TVSourceSetupView()
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                showPairing = true
                            } label: {
                                Label("Pair Device", systemImage: "qrcode")
                                    .font(.headline)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 16)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(TVTheme.accent)
                        }
                    }
                    .padding(54)
                } else {
                    TVMainShell(showSources: $showSources, showPairing: $showPairing)
                }
            }
            .sheet(isPresented: $showSources) {
                TVSourceSetupView(
                    onConnected: { showSources = false },
                    onClose: { showSources = false }
                )
            }
            .sheet(isPresented: $showPairing) {
                TVPairDeviceView(
                    onPaired: { showPairing = false },
                    onCancel: { showPairing = false }
                )
            }
            .task(id: store.activeSourceID) {
                guard let source = store.activeSource else { library.reset(); epg.clear(); return }
                if library.loadedSourceID != source.id { await library.load(source: source) }
                if epg.programmes.isEmpty && !epg.isLoading { await epg.load(for: source) }
            }
            .task {
                let inbox = TVCredentialTransferService()
                while !Task.isCancelled {
                    if TVSessionVault.readRefreshToken() != nil {
                        _ = try? await inbox.receivePending()
                    }
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                }
            }
            .task {
                while !Task.isCancelled {
                    if TVSessionVault.readRefreshToken() != nil {
                        try? await TVSyncService.shared.pullProgress()
                    }
                    try? await Task.sleep(nanoseconds: 20_000_000_000)
                }
            }
        }
    }
}

private struct TVBackground: View {
    var showHero: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                TVTheme.background
                LinearGradient(
                    colors: [TVTheme.background2, TVTheme.background, Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                TVTheme.heroGlow
                    .opacity(0.90)

                Image("APKPattern")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.10)
                    .blendMode(.screen)
                    .allowsHitTesting(false)

                if showHero {
                    Image("APKBrandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geo.size.width * 0.42, 700), height: min(geo.size.height * 0.28, 260), alignment: .top)
                        .padding(.top, 24)
                        .opacity(0.15)
                        .blur(radius: 1.5)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}


private enum TVMainSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case live = "Live TV"
    case movies = "Movies"
    case series = "Series"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .live: return "tv.fill"
        case .movies: return "film.fill"
        case .series: return "rectangle.stack.fill"
        }
    }
}

private enum TVTopFocus: Hashable {
    case section(TVMainSection)
    case pairing
    case sources
}

private struct TVMainShell: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    @Binding var showSources: Bool
    @Binding var showPairing: Bool
    @State private var section: TVMainSection = .home

    var body: some View {
        VStack(spacing: 0) {
            TVTopNavigation(section: $section, showSources: $showSources, showPairing: $showPairing)
                .padding(.horizontal, 64)
                .padding(.top, 26)
                .padding(.bottom, 18)
                .background(TVTheme.background.opacity(0.96))

            Group {
                switch section {
                case .home:
                    TVGhostHomeDashboard(section: $section)
                case .live:
                    TVLiveListBrowser()
                case .movies:
                    TVMovieGrid()
                case .series:
                    TVSeriesGrid()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(TVBackground())
    }
}

private struct TVTopNavigation: View {
    @Binding var section: TVMainSection
    @Binding var showSources: Bool
    @Binding var showPairing: Bool
    @FocusState private var focusedItem: TVTopFocus?

    var body: some View {
        HStack(spacing: 26) {
            Image("APKBrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 68, alignment: .leading)

            Spacer().frame(width: 16)

            ForEach(TVMainSection.allCases) { item in
                Button { section = item } label: {
                    TVTopNavLabel(
                        title: item.rawValue,
                        systemImage: item.systemImage,
                        selected: section == item,
                        focused: focusedItem == .section(item)
                    )
                }
                .buttonStyle(TVGhostFocusStyle())
                .focused($focusedItem, equals: .section(item))
            }

            Spacer()

            Button { showPairing = true } label: {
                TVTopNavLabel(
                    title: "Pair",
                    systemImage: "qrcode",
                    selected: false,
                    focused: focusedItem == .pairing
                )
            }
            .buttonStyle(TVGhostFocusStyle())
            .focused($focusedItem, equals: .pairing)

            Button { showSources = true } label: {
                TVTopNavLabel(
                    title: "Sources",
                    systemImage: "externaldrive.fill",
                    selected: false,
                    focused: focusedItem == .sources
                )
            }
            .buttonStyle(TVGhostFocusStyle())
            .focused($focusedItem, equals: .sources)
        }
        .focusSection()
    }
}

private struct TVTopNavLabel: View {
    let title: String
    let systemImage: String?
    let selected: Bool
    let focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.headline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(
                    focused
                    ? TVTheme.accent.opacity(0.34)
                    : (selected ? TVTheme.accent.opacity(0.22) : TVTheme.chip.opacity(0.76))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(
                    focused ? TVTheme.accentBright : (selected ? TVTheme.accent.opacity(0.70) : TVTheme.border),
                    lineWidth: focused ? 3 : 1
                )
        )
        .scaleEffect(focused ? 1.06 : 1.0)
        .shadow(color: TVTheme.accent.opacity(focused ? 0.30 : 0), radius: focused ? 14 : 0)
        .animation(.easeOut(duration: 0.12), value: focused)
    }
}

private struct TVGhostHomeDashboard: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    @ObservedObject private var progress = TVPlaybackProgressStore.shared
    @Binding var section: TVMainSection

    private var featuredMovies: [VODStream] { Array(library.movies.prefix(6)) }
    private var featuredSeries: [Series] { Array(library.series.prefix(6)) }
    private var continueRecords: [TVPlaybackProgressRecord] {
        progress.active(limit: 8).filter { record in
            store.sources.contains(where: { $0.id == record.sourceID })
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TVGhostHomeHero(section: $section)

                if !continueRecords.isEmpty {
                    Text("Continue Watching")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    TVHomeContinueShelf(records: continueRecords)
                }

                TVHomeLiveRow(section: $section)

                if !featuredMovies.isEmpty {
                    TVHomeSectionHeader(title: "Movies", action: { section = .movies })
                    HStack(alignment: .top, spacing: 24) {
                        TVHomeLaunchCard(
                            title: "Movies",
                            subtitle: "Browse your movie library",
                            icon: "film.fill",
                            action: { section = .movies }
                        )
                        TVMovieShelf(items: featuredMovies)
                    }
                }

                if !featuredSeries.isEmpty {
                    TVHomeSectionHeader(title: "Series", action: { section = .series })
                    HStack(alignment: .top, spacing: 24) {
                        TVHomeLaunchCard(
                            title: "Series",
                            subtitle: "Binge your favorites",
                            icon: "rectangle.stack.fill",
                            action: { section = .series }
                        )
                        TVSeriesShelf(items: featuredSeries)
                    }
                }
            }
            .padding(.horizontal, 64)
            .padding(.bottom, 80)
        }
        .background(TVTheme.background)
    }
}

private struct TVGhostHomeHero: View {
    @Binding var section: TVMainSection

    var body: some View {
        ZStack(alignment: .leading) {
            Image("GhostHomeHero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [Color.black.opacity(0.96), Color.black.opacity(0.70), Color.black.opacity(0.18)],
                startPoint: .leading,
                endPoint: .trailing
            )

            LinearGradient(
                colors: [Color.clear, TVTheme.accent.opacity(0.12), Color.black.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("ENTERTAINMENT")
                    .font(.system(size: 31, weight: .medium))
                    .tracking(12)
                    .foregroundStyle(.white)
                Text("WITHOUT LIMITS")
                    .font(.system(size: 31, weight: .medium))
                    .tracking(12)
                    .foregroundStyle(TVTheme.accentBright)
                Text("Live TV  •  Movies  •  Series  •  Your Way")
                    .font(.headline.weight(.medium))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, 2)

                HStack(spacing: 18) {
                    Button { section = .movies } label: {
                        Label("Continue Watching", systemImage: "play.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .frame(height: 54)
                            .background(TVTheme.accent.opacity(0.78), in: Capsule())
                            .overlay(Capsule().stroke(TVTheme.accentBright, lineWidth: 2))
                    }
                    .buttonStyle(TVGhostFocusStyle())
                    .tvGhostFocus(cornerRadius: 27)

                    Button { section = .live } label: {
                        Label("Browse Content", systemImage: "square.grid.2x2")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .frame(height: 54)
                            .background(Color.black.opacity(0.48), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.24), lineWidth: 1))
                    }
                    .buttonStyle(TVGhostFocusStyle())
                    .tvGhostFocus(cornerRadius: 27)
                }
                .padding(.top, 8)
            }
            .padding(.leading, 40)
            .padding(.vertical, 30)
        }
        .frame(height: 275)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(TVTheme.border, lineWidth: 1))
        .shadow(color: TVTheme.accent.opacity(0.14), radius: 24)
    }
}

private struct TVHomeContinueShelf: View {
    let records: [TVPlaybackProgressRecord]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                ForEach(records) { record in
                    NavigationLink {
                        TVResumeContentDestination(record: record)
                    } label: {
                        TVHomeContinueCard(record: record)
                    }
                    .buttonStyle(TVGhostFocusStyle())
                }
            }
            .padding(.vertical, 12)
        }
    }
}

private struct TVHomeContinueCard: View {
    let record: TVPlaybackProgressRecord

    private var progressValue: Double {
        guard record.durationSeconds > 0 else { return 0 }
        return min(max(record.positionSeconds / record.durationSeconds, 0), 1)
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                TVTheme.cardGradient
                Image(systemName: record.contentKind == .episode ? "play.square.stack.fill" : "film.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(TVTheme.accentBright)
            }
            .frame(width: 170, height: 98)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(TVDisplayFormatter.cleanTitle(record.title ?? (record.contentKind == .episode ? "Episode" : "Movie")))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack {
                    Text(record.contentKind == .episode ? "EPISODE" : "MOVIE")
                    Spacer()
                    Text("\(Int(progressValue * 100))%")
                        .monospacedDigit()
                }
                .font(.caption.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(TVTheme.muted)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.13))
                        Capsule()
                            .fill(TVTheme.accent)
                            .frame(width: max(4, geometry.size.width * progressValue))
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, 18)
            .frame(width: 260, height: 98, alignment: .leading)
        }
        .frame(width: 430, height: 98)
        .background(TVTheme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(TVTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .tvGhostFocus(cornerRadius: 16)
    }
}

private struct TVResumeContentDestination: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel

    let record: TVPlaybackProgressRecord

    @State private var movie: VODStream?
    @State private var episode: Episode?
    @State private var series: Series?
    @State private var episodes: [Episode] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let movie {
                TVPlayerView(
                    title: movie.name,
                    urlString: movie.url ?? "",
                    contentID: String(movie.id)
                )
            } else if let episode, let series {
                TVPlayerView(
                    title: episode.title,
                    urlString: episode.url ?? "",
                    contentID: episode.id,
                    seriesContext: TVSeriesPlaybackContext(
                        seriesID: series.id,
                        seriesTitle: series.name,
                        plot: series.plot,
                        episodes: episodes,
                        initialEpisodeID: episode.id
                    )
                )
            } else if loading {
                ZStack {
                    TVTheme.background.ignoresSafeArea()
                    ProgressView("Preparing playback…")
                        .tint(TVTheme.accent)
                        .foregroundStyle(.white)
                }
            } else {
                ZStack {
                    TVTheme.background.ignoresSafeArea()
                    TVPlaybackMessage(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Unable to resume",
                        message: errorMessage ?? "This item is no longer available from the saved source."
                    )
                }
            }
        }
        .task(id: record.id) {
            await prepare()
        }
    }

    @MainActor
    private func prepare() async {
        loading = true
        errorMessage = nil

        guard let source = store.sources.first(where: { $0.id == record.sourceID }) else {
            errorMessage = "The source used for this item is not available on this Apple TV."
            loading = false
            return
        }

        if store.activeSourceID != source.id {
            store.setActive(source)
        }
        if library.loadedSourceID != source.id {
            await library.load(source: source)
        }

        switch record.contentKind {
        case .vod:
            guard let id = Int(record.contentID),
                  let resolved = library.movies.first(where: { $0.id == id }) else {
                errorMessage = "The movie could not be found in this source."
                loading = false
                return
            }
            movie = resolved

        case .episode:
            guard let seriesID = record.seriesID,
                  let resolvedSeries = library.series.first(where: { $0.id == seriesID }),
                  source.kind == .xtream,
                  let server = source.serverURL,
                  let username = source.username,
                  let password = source.password else {
                errorMessage = "The episode source is not available on this Apple TV."
                loading = false
                return
            }
            do {
                let loaded = try await XtreamClient(
                    serverURL: server,
                    username: username,
                    password: password
                ).seriesInfo(seriesId: seriesID)
                guard let resolvedEpisode = loaded.first(where: { $0.id == record.contentID }) else {
                    errorMessage = "The episode is no longer available from this source."
                    loading = false
                    return
                }
                series = resolvedSeries
                episodes = loaded
                episode = resolvedEpisode
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        loading = false
    }
}

private struct TVHomeLiveRow: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Binding var section: TVMainSection

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TVHomeSectionHeader(title: "Live TV", action: { section = .live })
            HStack(spacing: 20) {
                TVHomeLaunchCard(
                    title: "Live TV",
                    subtitle: "Watch live channels",
                    icon: "tv.fill",
                    action: { section = .live }
                )

                ForEach(Array(library.liveCategories.prefix(5))) { category in
                    Button { section = .live } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Spacer()
                            Image(systemName: "waveform.path.ecg.rectangle")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(TVTheme.accentBright)
                            Text(TVDisplayFormatter.cleanCategory(category.name))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .padding(18)
                        .frame(width: 190, height: 112, alignment: .leading)
                        .background(TVTheme.cardGradient, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(TVTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(TVGhostFocusStyle())
                    .tvGhostFocus(cornerRadius: 16)
                }
            }
        }
    }
}

private struct TVHomeLaunchCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 66)
                    .background(TVTheme.accent.opacity(0.48), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(TVTheme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.headline.bold())
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(16)
            .frame(width: 310, height: 112)
            .background(TVTheme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(TVTheme.border, lineWidth: 1))
        }
        .buttonStyle(TVGhostFocusStyle())
        .tvGhostFocus(cornerRadius: 16)
    }
}

private struct TVHomeSectionHeader: View {
    let title: String
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button(action: action) {
                HStack(spacing: 8) {
                    Text("See All")
                    Image(systemName: "chevron.right")
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
            }
            .buttonStyle(TVGhostFocusStyle())
        }
    }
}

private struct TVShelfHeader: View {
    let title: String
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Spacer()
            Button(action: action) {
                Text("See All")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(TVTheme.accentBright)
            }
            .buttonStyle(TVGhostFocusStyle())
        }
    }
}

private struct TVHeroBanner: View {
    let series: Series?
    let openSeries: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(TVTheme.cardGradient)

            if let cover = series?.cover {
                TVRemoteImage(urlString: cover, systemImage: "rectangle.stack.fill", contentMode: .fill, iconSize: 70)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .opacity(0.42)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.20), .white],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            LinearGradient(
                colors: [TVTheme.background.opacity(0.95), TVTheme.background.opacity(0.72), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))

            VStack(alignment: .leading, spacing: 16) {
                Image("APKBrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 70, alignment: .leading)

                Text(series.map { TVDisplayFormatter.cleanTitle($0.name) } ?? "Your streams. Your screen.")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: 720, alignment: .leading)

                if let plot = series?.plot, !plot.isEmpty {
                    Text(plot)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(3)
                        .frame(maxWidth: 720, alignment: .leading)
                } else {
                    Text("Movies, TV shows and live channels from your authorized sources.")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Button(action: openSeries) {
                    Label("Browse TV Shows", systemImage: "play.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(TVTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(TVGhostFocusStyle())
            }
            .padding(40)
        }
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(TVTheme.border, lineWidth: 1))
    }
}

private struct TVSeriesShelf: View {
    let items: [Series]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 26) {
                ForEach(items) { show in
                    NavigationLink { TVSeriesDetail(series: show) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            TVPosterArtwork(urlString: show.cover, system: "rectangle.stack.fill")
                                .frame(width: 190, height: 285)
                            Text(TVDisplayFormatter.cleanTitle(show.name))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .frame(width: 190, alignment: .leading)
                        }
                        .frame(width: 190, alignment: .leading)
                    }
                    .buttonStyle(TVGhostFocusStyle())
                }
            }
            .padding(.vertical, 18)
        }
    }
}

private struct TVLiveListBrowser: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var epg: EPGService
    @State private var selectedCategory: Category?
    @State private var visibleLimit = 100
    @State private var previewChannel: Channel?
    @State private var previewWorkItem: DispatchWorkItem?
    @FocusState private var focusedCategoryID: String?
    @FocusState private var focusedChannelID: String?

    private var channels: [Channel] { library.channels(in: selectedCategory) }
    private var visibleChannels: [Channel] { Array(channels.prefix(visibleLimit)) }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        selectedCategory = nil
                        visibleLimit = 100
                    } label: {
                        TVLiveSidebarChip(
                            title: "All Channels",
                            selected: selectedCategory == nil,
                            focused: focusedCategoryID == "__all__"
                        )
                    }
                    .buttonStyle(TVGhostFocusStyle())
                    .focused($focusedCategoryID, equals: "__all__")

                    ForEach(library.liveCategories) { category in
                        Button {
                            selectedCategory = category
                            visibleLimit = 100
                        } label: {
                            TVLiveSidebarChip(
                                title: category.name,
                                selected: selectedCategory == category,
                                focused: focusedCategoryID == category.id
                            )
                        }
                        .buttonStyle(TVGhostFocusStyle())
                        .focused($focusedCategoryID, equals: category.id)
                    }
                }
                .padding(.vertical, 8)
                .focusSection()
            }
            .frame(width: 420)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedCategory?.name ?? "Live TV")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(channels.count) CHANNELS")
                            .font(.headline.weight(.semibold))
                            .tracking(1.3)
                            .foregroundStyle(TVTheme.accentBright)
                    }
                    Spacer()
                }

                HStack(alignment: .top, spacing: 22) {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(visibleChannels.enumerated()), id: \.element.id) { index, channel in
                                NavigationLink {
                                    TVPlayerView(
                                        title: channel.name,
                                        urlString: channel.url,
                                        epgChannelId: channel.streamId.map(String.init)
                                    )
                                } label: {
                                    TVLiveListRow(
                                        index: index + 1,
                                        channel: channel,
                                        now: epg.nowPlaying(channel: channel),
                                        next: epg.upcoming(channel: channel, limit: 1).first
                                    )
                                }
                                .buttonStyle(TVGhostFocusStyle())
                                .focused($focusedChannelID, equals: channel.id)
                                .task(id: channel.streamId) {
                                    if let source = store.activeSource {
                                        await epg.ensureProviderEPG(for: channel, source: source)
                                    }
                                }
                                .onAppear {
                                    if channel.id == visibleChannels.last?.id, visibleLimit < channels.count {
                                        visibleLimit = min(channels.count, visibleLimit + 60)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 70)
                        .focusSection()
                    }

                    TVLivePreviewPanel(
                        channel: previewChannel,
                        now: previewChannel.flatMap { epg.nowPlaying(channel: $0) },
                        next: previewChannel.flatMap { epg.upcoming(channel: $0, limit: 1).first }
                    )
                    .frame(width: 500)
                }
            }
        }
        .padding(.horizontal, 64)
        .padding(.top, 24)
        .background(TVBackground(showHero: false))
        .onAppear {
            if focusedCategoryID == nil && focusedChannelID == nil {
                focusedCategoryID = "__all__"
            }
        }
        .onChange(of: focusedChannelID) { channelID in
            guard let channelID,
                  let channel = channels.first(where: { $0.id == channelID }) else {
                cancelPreview()
                return
            }
            schedulePreview(for: channel)
        }
        .onChange(of: selectedCategory) { _ in
            cancelPreview(clearCurrent: true)
        }
        .onDisappear {
            cancelPreview(clearCurrent: true)
        }
    }

    private func schedulePreview(for channel: Channel) {
        previewWorkItem?.cancel()
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.18)) {
                previewChannel = channel
            }
        }
        previewWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
    }

    private func cancelPreview(clearCurrent: Bool = false) {
        previewWorkItem?.cancel()
        previewWorkItem = nil
        if clearCurrent { previewChannel = nil }
    }

    private func epgKey(for channel: Channel) -> String {
        channel.tvgId ?? channel.streamId.map(String.init) ?? channel.id
    }
}


private struct TVLivePreviewPanel: View {
    let channel: Channel?
    let now: EPGProgramme?
    let next: EPGProgramme?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black)

                if let channel {
                    TVLivePreviewPlayer(urlString: channel.url)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .transition(.opacity)
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "play.rectangle.on.rectangle")
                            .font(.system(size: 54, weight: .light))
                            .foregroundStyle(TVTheme.accentBright)
                        Text("Focus a channel to preview")
                            .font(.headline)
                            .foregroundStyle(TVTheme.muted)
                    }
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(TVTheme.accent.opacity(0.45), lineWidth: 1))

            if let channel {
                Text(TVDisplayFormatter.cleanTitle(channel.name))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let now {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("NOW")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TVTheme.accentBright)
                            Text(now.title)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.92))
                                .lineLimit(2)
                        }
                        TVLiveEPGProgress(start: now.start, stop: now.stop)
                        if let next {
                            Text("NEXT  \(next.title)")
                                .font(.caption)
                                .foregroundStyle(TVTheme.muted)
                                .lineLimit(2)
                        }
                    }
                }

                Text("PREVIEW • MUTED")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(TVTheme.accentBright.opacity(0.9))
            }
        }
        .padding(16)
        .background(TVTheme.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(TVTheme.border, lineWidth: 1))
    }
}

private struct TVLivePreviewPlayer: UIViewRepresentable {
    let urlString: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PreviewPlayerView {
        let view = PreviewPlayerView()
        context.coordinator.attach(to: view)
        context.coordinator.play(urlString: urlString)
        return view
    }

    func updateUIView(_ view: PreviewPlayerView, context: Context) {
        context.coordinator.attach(to: view)
        context.coordinator.play(urlString: urlString)
    }

    static func dismantleUIView(_ uiView: PreviewPlayerView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        private let player = AVPlayer()
        private var currentURLString: String?

        init() {
            player.isMuted = true
            player.automaticallyWaitsToMinimizeStalling = true
        }

        func attach(to view: PreviewPlayerView) {
            if view.playerLayer.player !== player {
                view.playerLayer.player = player
            }
        }

        func play(urlString: String) {
            guard currentURLString != urlString else { return }
            currentURLString = urlString
            player.pause()
            player.replaceCurrentItem(with: nil)
            guard let url = previewURL(from: urlString) else { return }

            let item = AVPlayerItem(url: url)
            item.preferredForwardBufferDuration = 3
            item.preferredPeakBitRate = 6_000_000
            player.replaceCurrentItem(with: item)
            player.isMuted = true
            player.play()
        }

        func stop() {
            currentURLString = nil
            player.pause()
            player.replaceCurrentItem(with: nil)
        }

        private func previewURL(from string: String) -> URL? {
            guard let original = URL(string: string) else { return nil }
            if original.pathExtension.lowercased() == "ts" {
                let absolute = original.absoluteString
                let hls = String(absolute.dropLast(3)) + ".m3u8"
                return URL(string: hls) ?? original
            }
            return original
        }
    }

    final class PreviewPlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            playerLayer.videoGravity = .resizeAspect
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

private struct TVLiveSidebarChip: View {
    let title: String
    let selected: Bool
    let focused: Bool

    var body: some View {
        HStack {
            Image(systemName: selected ? "rectangle.grid.1x2.fill" : "rectangle.grid.1x2")
                .foregroundStyle(selected ? TVTheme.accentBright : TVTheme.muted)
            Text(TVDisplayFormatter.cleanCategory(title))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 68)
        .background((focused || selected) ? TVTheme.accent.opacity(focused ? 0.34 : 0.20) : TVTheme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focused ? TVTheme.accentBright : (selected ? TVTheme.accent : TVTheme.border), lineWidth: focused ? 3 : (selected ? 2 : 1))
        )
        .scaleEffect(focused ? 1.035 : 1.0)
        .shadow(color: TVTheme.accent.opacity(focused ? 0.28 : 0), radius: focused ? 12 : 0)
        .animation(.easeOut(duration: 0.12), value: focused)
    }
}

private struct TVLiveListRow: View {
    let index: Int
    let channel: Channel
    let now: EPGProgramme?
    let next: EPGProgramme?

    var body: some View {
        HStack(spacing: 18) {
            Text("\(index)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(TVTheme.muted)
                .frame(width: 46, alignment: .trailing)

            TVRemoteImage(urlString: channel.logo, systemImage: "tv", contentMode: .fit, iconSize: 32)
                .frame(width: 88, height: 50)
                .padding(6)
                .background(TVTheme.background, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 10) {
                    Text(TVDisplayFormatter.cleanTitle(channel.name))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if now != nil {
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(TVTheme.accentBright)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(TVTheme.accent.opacity(0.18), in: Capsule())
                    }
                }

                if let now {
                    HStack(spacing: 8) {
                        Text("NOW")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TVTheme.accentBright)
                        Text(now.title)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                    }
                    TVLiveEPGProgress(start: now.start, stop: now.stop)
                    if let next {
                        HStack(spacing: 8) {
                            Text("NEXT")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(TVTheme.muted)
                            Text(next.title)
                                .font(.caption)
                                .foregroundStyle(TVTheme.muted)
                                .lineLimit(1)
                        }
                    }
                } else if let group = channel.group, !group.isEmpty {
                    Text(TVDisplayFormatter.cleanCategory(group))
                        .font(.caption)
                        .foregroundStyle(TVTheme.muted)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "play.fill")
                .foregroundStyle(TVTheme.accentBright)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: now == nil ? 72 : 112)
        .background(TVTheme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(TVTheme.border, lineWidth: 1))
        .tvGhostFocus(cornerRadius: 14)
    }
}

private struct TVLiveEPGProgress: View {
    let start: Date
    let stop: Date

    private var progress: CGFloat {
        let total = stop.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return CGFloat(min(max(Date().timeIntervalSince(start) / total, 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(TVTheme.accent)
                    .frame(width: max(8, geo.size.width * progress))
            }
        }
        .frame(height: 5)
        .frame(maxWidth: 520)
    }
}

private struct TVChannelShelf: View {
    let items: [Channel]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 28) {
                ForEach(items) { channel in
                    NavigationLink { TVPlayerView(title: channel.name, urlString: channel.url) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            TVArtwork(urlString: channel.logo, system: "tv")
                                .frame(width: 260, height: 150)
                            Text(channel.name).font(.headline).foregroundStyle(.white).lineLimit(1)
                        }
                        .frame(width: 260, alignment: .leading)
                            .tvGhostFocus(cornerRadius: 18)
                    }
                    .buttonStyle(TVGhostFocusStyle())
                }
            }
            .padding(.vertical, 18)
        }
    }
}

private struct TVMovieShelf: View {
    let items: [VODStream]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 28) {
                ForEach(items) { movie in
                    NavigationLink { TVPlayerView(title: movie.name, urlString: movie.url ?? "", contentID: String(movie.id)) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            TVPosterArtwork(urlString: movie.icon, system: "film")
                                .frame(width: 190, height: 285)
                            Text(TVDisplayFormatter.cleanTitle(movie.name))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .frame(width: 190, alignment: .leading)
                        }
                        .frame(width: 190, alignment: .leading)
                    }
                    .buttonStyle(TVGhostFocusStyle())
                }
            }
            .padding(.vertical, 18)
        }
    }
}

private final class TVImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private var task: URLSessionDataTask?
    private var representedURL: URL?

    private static let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 500
        cache.totalCostLimit = 96 * 1024 * 1024
        return cache
    }()

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024,
            diskPath: "GhostStreamTVArtwork"
        )
        return URLSession(configuration: configuration)
    }()

    func load(_ rawURL: String?) {
        guard let rawURL, let url = Self.normalizedURL(rawURL) else {
            cancel()
            representedURL = nil
            image = nil
            return
        }

        if representedURL == url, image != nil { return }

        cancel()
        representedURL = url

        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }

        image = nil
        var request = URLRequest(url: url)
        request.setValue("GhostStreamTV/1.0", forHTTPHeaderField: "User-Agent")

        task = Self.session.dataTask(with: request) { [weak self] data, response, error in
            guard error == nil,
                  let data,
                  let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode),
                  let decoded = UIImage(data: data) else { return }

            let memoryCost = decoded.cgImage.map { $0.bytesPerRow * $0.height } ?? data.count
            Self.cache.setObject(decoded, forKey: url as NSURL, cost: memoryCost)
            DispatchQueue.main.async {
                guard self?.representedURL == url else { return }
                self?.image = decoded
            }
        }
        task?.resume()
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit { cancel() }

    private static func normalizedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = URL(string: trimmed) { return direct }
        guard let escaped = trimmed.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else { return nil }
        return URL(string: escaped)
    }
}

private struct TVRemoteImage: View {
    let urlString: String?
    let systemImage: String
    var contentMode: ContentMode = .fill
    var iconSize: CGFloat = 50

    @StateObject private var loader = TVImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: iconSize, weight: .light))
                    .foregroundStyle(TVTheme.accent.opacity(0.68))
            }
        }
        .onAppear { loader.load(urlString) }
        .onChange(of: urlString) { newValue in loader.load(newValue) }
        .onDisappear { loader.cancel() }
    }
}

private struct TVArtwork: View {
    let urlString: String?
    let system: String
    var contentMode: ContentMode = .fill
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(TVTheme.cardGradient)
            TVRemoteImage(urlString: urlString, systemImage: system, contentMode: contentMode)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(TVTheme.border, lineWidth: 1))
    }
}

private struct TVPosterArtwork: View {
    let urlString: String?
    let system: String

    var body: some View {
        TVArtwork(urlString: urlString, system: system, contentMode: .fill)
            .tvPosterFocus(cornerRadius: 18)
    }
}

private struct TVLiveChannelCard: View {
    let channel: Channel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(TVTheme.cardGradient)

                TVRemoteImage(
                    urlString: channel.logo,
                    systemImage: "tv",
                    contentMode: .fit,
                    iconSize: 52
                )
                .padding(20)
            }
            .frame(width: TVMediaLayout.liveCardWidth)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(TVTheme.accent.opacity(0.34), lineWidth: 1)
            )

            Text(TVDisplayFormatter.cleanTitle(channel.name))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(width: TVMediaLayout.liveCardWidth, height: 56, alignment: .topLeading)

            if let group = channel.group, !group.isEmpty {
                Text(TVDisplayFormatter.cleanCategory(group).uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(TVTheme.accent.opacity(0.82))
                    .lineLimit(1)
                    .frame(width: TVMediaLayout.liveCardWidth, alignment: .leading)
            }
        }
        .frame(width: TVMediaLayout.liveCardWidth, alignment: .topLeading)
        .padding(.bottom, 6)
        .tvGhostFocus(cornerRadius: 18)
    }
}

private struct TVPosterCard: View {
    let title: String
    let imageURL: String?
    let systemImage: String
    let metadata: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TVPosterArtwork(urlString: imageURL, system: systemImage)
                .frame(width: TVMediaLayout.posterWidth)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)

            Text(TVDisplayFormatter.cleanTitle(title))
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(width: TVMediaLayout.posterWidth, height: 54, alignment: .topLeading)

            if let metadata, !metadata.isEmpty {
                Text(metadata.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.7)
                    .foregroundStyle(TVTheme.accentBright.opacity(0.92))
                    .lineLimit(1)
                    .frame(width: TVMediaLayout.posterWidth, alignment: .leading)
            }
        }
        .frame(width: TVMediaLayout.posterWidth, alignment: .topLeading)
        .padding(.bottom, 6)
    }
}

private struct TVMediaScreenHeader: View {
    let title: String
    let countText: String

    var body: some View {
        HStack(spacing: 18) {
            Image("APKBrandLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(TVTheme.accent.opacity(0.55), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                Text(countText.uppercased())
                    .font(.headline.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(TVTheme.accent)
            }

            Spacer()

            Image("APKBrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 58, alignment: .trailing)
                .opacity(0.82)
        }
        .padding(.horizontal, TVMediaLayout.horizontalInset)
        .padding(.top, 30)
        .padding(.bottom, 16)
    }
}

private struct TVProviderCategoryStrip: View {
    let allTitle: String
    let categories: [Category]
    let totalCount: Int
    let countForCategory: (Category) -> Int
    @Binding var selection: Category?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                Button { selection = nil } label: {
                    TVCompactFilterChip(title: allTitle, count: totalCount, selected: selection == nil)
                }
                .buttonStyle(TVGhostFocusStyle())

                ForEach(categories) { category in
                    Button { selection = category } label: {
                        TVCompactFilterChip(
                            title: category.name.trimmingCharacters(in: .whitespacesAndNewlines),
                            count: countForCategory(category),
                            selected: selection == category
                        )
                    }
                    .buttonStyle(TVGhostFocusStyle())
                }
            }
            .padding(.horizontal, TVMediaLayout.horizontalInset)
            .padding(.vertical, 16)
        }
        .background(TVTheme.background.opacity(0.86))
    }
}

private struct TVCompactFilterChip: View {
    let title: String
    let count: Int?
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.subheadline.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let count {
                Text("\(count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(selected ? .white.opacity(0.82) : TVTheme.muted)
            }
        }
        .padding(.horizontal, 20)
        .frame(minWidth: 150, maxWidth: 300, minHeight: 62)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(selected ? TVTheme.accent.opacity(0.18) : TVTheme.chip)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? TVTheme.accent : TVTheme.accent.opacity(0.28), lineWidth: selected ? 2 : 1)
        )
        .tvGhostFocus(cornerRadius: 14)
    }
}

private struct TVLiveGrid: View {
    @EnvironmentObject private var library: LibraryViewModel
    @State private var selectedCategory: Category?

    private var filteredChannels: [Channel] {
        library.channels(in: selectedCategory)
    }

    private var providerCategories: [Category] {
        library.liveCategories
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TVMediaScreenHeader(
                    title: "Live TV",
                    countText: "\(filteredChannels.count) channels"
                )

                if !providerCategories.isEmpty {
                    TVProviderCategoryStrip(
                        allTitle: "All Channels",
                        categories: providerCategories,
                        totalCount: library.channels.count,
                        countForCategory: { library.liveCount(for: $0) },
                        selection: $selectedCategory
                    )
                }

                ScrollView {
                    LazyVGrid(
                        columns: TVMediaLayout.liveGridColumns(for: geometry.size.width),
                        alignment: .center,
                        spacing: 34
                    ) {
                        ForEach(filteredChannels) { channel in
                            NavigationLink {
                                TVPlayerView(title: channel.name, urlString: channel.url)
                            } label: {
                                TVLiveChannelCard(channel: channel)
                            }
                            .buttonStyle(TVGhostFocusStyle())
                        }
                    }
                    .padding(.horizontal, TVMediaLayout.horizontalInset)
                    .padding(.top, 28)
                    .padding(.bottom, 80)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("")
        .background(TVBackground())
    }
}

private struct TVMovieGrid: View {
    @EnvironmentObject private var library: LibraryViewModel
    @State private var selectedMovieCategory: Category?
    @State private var visibleMovieLimit = TVMediaPaging.initialLimit

    private var filteredMovies: [VODStream] {
        library.movies(in: selectedMovieCategory)
    }

    private var visibleMovies: [VODStream] {
        Array(filteredMovies.prefix(visibleMovieLimit))
    }

    private func loadMoreMoviesIfNeeded(current movie: VODStream) {
        guard visibleMovies.suffix(6).contains(where: { $0.id == movie.id }) else { return }
        let next = TVMediaPaging.nextLimit(current: visibleMovieLimit, total: filteredMovies.count)
        if next != visibleMovieLimit { visibleMovieLimit = next }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TVMediaScreenHeader(
                    title: selectedMovieCategory?.name ?? "Movies",
                    countText: "\(filteredMovies.count) titles"
                )

                if !library.movieCategories.isEmpty {
                    TVProviderCategoryStrip(
                        allTitle: "All Movies",
                        categories: library.movieCategories,
                        totalCount: library.movies.count,
                        countForCategory: { library.movieCount(for: $0) },
                        selection: $selectedMovieCategory
                    )
                }

                ScrollView {
                    if filteredMovies.isEmpty {
                        TVEmptyCategoryState(title: selectedMovieCategory?.name ?? "Movies")
                            .padding(.top, 100)
                    } else {
                        LazyVGrid(
                            columns: TVMediaLayout.posterGridColumns(for: geometry.size.width),
                            alignment: .center,
                            spacing: 38
                        ) {
                            ForEach(visibleMovies) { movie in
                                NavigationLink {
                                    TVPlayerView(title: movie.name, urlString: movie.url ?? "", contentID: String(movie.id))
                                } label: {
                                    TVPosterCard(
                                        title: movie.name,
                                        imageURL: movie.icon,
                                        systemImage: "film",
                                        metadata: library.movieCategoryName(for: movie.categoryId)
                                    )
                                }
                                .buttonStyle(TVGhostFocusStyle())
                                .onAppear { loadMoreMoviesIfNeeded(current: movie) }
                            }
                        }
                        .padding(.horizontal, TVMediaLayout.horizontalInset)
                        .padding(.top, 28)
                        .padding(.bottom, 80)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .onChange(of: selectedMovieCategory) { _ in
            visibleMovieLimit = TVMediaPaging.initialLimit
        }
        .navigationTitle("")
        .background(TVBackground())
    }
}

private struct TVSeriesGrid: View {
    @EnvironmentObject private var library: LibraryViewModel
    @State private var selectedSeriesCategory: Category?
    @State private var visibleSeriesLimit = TVMediaPaging.initialLimit

    private var filteredSeries: [Series] {
        library.shows(in: selectedSeriesCategory)
    }

    private var visibleSeries: [Series] {
        Array(filteredSeries.prefix(visibleSeriesLimit))
    }

    private func loadMoreSeriesIfNeeded(current show: Series) {
        guard visibleSeries.suffix(6).contains(where: { $0.id == show.id }) else { return }
        let next = TVMediaPaging.nextLimit(current: visibleSeriesLimit, total: filteredSeries.count)
        if next != visibleSeriesLimit { visibleSeriesLimit = next }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TVMediaScreenHeader(
                    title: selectedSeriesCategory?.name ?? "Series",
                    countText: "\(filteredSeries.count) titles"
                )

                if !library.seriesCategories.isEmpty {
                    TVProviderCategoryStrip(
                        allTitle: "All Series",
                        categories: library.seriesCategories,
                        totalCount: library.series.count,
                        countForCategory: { library.seriesCount(for: $0) },
                        selection: $selectedSeriesCategory
                    )
                }

                ScrollView {
                    if filteredSeries.isEmpty {
                        TVEmptyCategoryState(title: selectedSeriesCategory?.name ?? "Series")
                            .padding(.top, 100)
                    } else {
                        LazyVGrid(
                            columns: TVMediaLayout.posterGridColumns(for: geometry.size.width),
                            alignment: .center,
                            spacing: 38
                        ) {
                            ForEach(visibleSeries) { series in
                                NavigationLink { TVSeriesDetail(series: series) } label: {
                                    TVPosterCard(
                                        title: series.name,
                                        imageURL: series.cover,
                                        systemImage: "rectangle.stack",
                                        metadata: library.seriesCategoryName(for: series.categoryId)
                                    )
                                }
                                .buttonStyle(TVGhostFocusStyle())
                                .onAppear { loadMoreSeriesIfNeeded(current: series) }
                            }
                        }
                        .padding(.horizontal, TVMediaLayout.horizontalInset)
                        .padding(.top, 28)
                        .padding(.bottom, 80)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .onChange(of: selectedSeriesCategory) { _ in
            visibleSeriesLimit = TVMediaPaging.initialLimit
        }
        .navigationTitle("")
        .background(TVBackground())
    }
}

private struct TVEmptyCategoryState: View {
    let title: String
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "rectangle.stack.badge.minus")
                .font(.system(size: 62, weight: .light))
                .foregroundStyle(TVTheme.accent.opacity(0.8))
            Text("No \(title) titles")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("This provider did not return any titles in this category.")
                .font(.headline)
                .foregroundStyle(TVTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TVSeasonPickerChip: View {
    let label: String
    let selected: Bool

    var body: some View {
        Text(label)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? TVTheme.accent.opacity(0.20) : TVTheme.chip)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? TVTheme.accentBright : TVTheme.border, lineWidth: selected ? 2 : 1)
            )
            .tvGhostFocus(cornerRadius: 14)
    }
}

private struct TVEpisodeCard: View {
    let seriesCover: String?
    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TVPosterArtwork(urlString: episode.image ?? seriesCover, system: "play.rectangle.fill")
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)

            HStack(spacing: 10) {
                Text(String(format: "S%02d • E%02d", episode.season, episode.episodeNum))
                    .font(.caption.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(TVTheme.accentBright)
                if let duration = episode.duration, !duration.isEmpty {
                    Text(duration)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TVTheme.muted)
                }
            }

            Text(TVDisplayFormatter.cleanTitle(episode.title))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let plot = episode.plot, !plot.isEmpty {
                Text(plot)
                    .font(.caption)
                    .foregroundStyle(TVTheme.muted)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(TVTheme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(TVTheme.border, lineWidth: 1)
        )
    }
}

private struct TVSeriesDetail: View {
    let series: Series
    @EnvironmentObject private var store: SourceStore
    @State private var episodes: [Episode] = []
    @State private var error: String?
    @State private var selectedSeason: Int?

    private var seasons: [Int] {
        Array(Set(episodes.map(\.season))).sorted()
    }

    private var filteredEpisodes: [Episode] {
        guard let selectedSeason else { return episodes }
        return episodes.filter { $0.season == selectedSeason }
    }

    private func seasonLabel(_ season: Int) -> String {
        "SEASON \(season)"
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .top, spacing: 28) {
                        TVPosterArtwork(urlString: series.cover, system: "rectangle.stack")
                            .frame(width: 260, height: 390)

                        VStack(alignment: .leading, spacing: 14) {
                            Text(TVDisplayFormatter.cleanTitle(series.name))
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white)
                            if let category = series.categoryId, !category.isEmpty {
                                Text(category)
                                    .font(.headline.weight(.semibold))
                                    .tracking(1.2)
                                    .foregroundStyle(TVTheme.accentBright)
                            }
                            if let plot = series.plot, !plot.isEmpty {
                                Text(plot)
                                    .font(.headline)
                                    .foregroundStyle(TVTheme.muted)
                                    .lineLimit(5)
                                    .frame(maxWidth: 760, alignment: .leading)
                            }
                            Text("\(episodes.count) EPISODES")
                                .font(.headline.weight(.bold))
                                .tracking(1.6)
                                .foregroundStyle(TVTheme.accent)
                        }
                        Spacer(minLength: 0)
                    }

                    if let error {
                        TVEmptyCategoryState(title: error)
                    } else if episodes.isEmpty {
                        ProgressView("Loading episodes…")
                            .tint(TVTheme.accent)
                            .foregroundStyle(.white)
                            .padding(.top, 80)
                            .frame(maxWidth: .infinity)
                    } else {
                        if !seasons.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(seasons, id: \.self) { season in
                                        Button { selectedSeason = season } label: {
                                            TVSeasonPickerChip(label: seasonLabel(season), selected: selectedSeason == season)
                                        }
                                        .buttonStyle(TVGhostFocusStyle())
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: max(3, min(4, Int((geometry.size.width - 160) / 320)))),
                            spacing: 24
                        ) {
                            ForEach(filteredEpisodes) { episode in
                                NavigationLink {
                                    TVPlayerView(title: episode.title, urlString: episode.url ?? "", seriesContext: TVSeriesPlaybackContext(seriesID: series.id, seriesTitle: series.name, plot: series.plot, episodes: episodes, initialEpisodeID: episode.id))
                                } label: {
                                    TVEpisodeCard(seriesCover: series.cover, episode: episode)
                                }
                                .buttonStyle(TVGhostFocusStyle())
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, TVMediaLayout.horizontalInset)
                .padding(.vertical, 44)
            }
        }
        .navigationTitle("")
        .background(TVBackground(showHero: false))
        .task { await loadEpisodes() }
    }

    private func loadEpisodes() async {
        if !episodes.isEmpty { return }

        guard let source = store.activeSource,
              source.kind == .xtream,
              let server = source.serverURL,
              let user = source.username,
              let pass = source.password else {
            error = "Series episodes require a provider login."
            return
        }

        error = nil
        do {
            let loaded = try await XtreamClient(serverURL: server, username: user, password: pass).seriesInfo(seriesId: series.id)
            await MainActor.run {
                error = nil
                episodes = loaded
                selectedSeason = loaded.map(\.season).min()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
}

private struct TVSeriesPlaybackContext {
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

private struct TVPlayerView: View {
    @EnvironmentObject private var epg: EPGService
    @EnvironmentObject private var store: SourceStore
    @ObservedObject private var playbackProgress = TVPlaybackProgressStore.shared
    let title: String
    let urlString: String
    var epgChannelId: String? = nil
    var contentID: String? = nil
    var seriesContext: TVSeriesPlaybackContext? = nil

    @State private var currentEpisodeID: String?
    @State private var tryOriginalNativeURL = false
    @State private var useCompatibilityEngine = false
    @State private var playbackError: String?
    @State private var nativeAttemptsExhausted = false
    @State private var compatibilityPlaying = true
    @State private var compatibilityCommand = 0
    @State private var tvAudioTracks: [TVMediaTrack] = []
    @State private var tvSubtitleTracks: [TVMediaTrack] = []
    @State private var tvSelectedAudio: Int?
    @State private var tvSelectedSubtitle: Int?
    @State private var tvTrackCommand = 0
    @State private var episodeSwitchInProgress = false
    @State private var chromeVisible = true
    @State private var chromeHideWorkItem: DispatchWorkItem?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var requestedPosition: Double?
    @State private var playbackEndedToken = 0
    @State private var didRestoreProgress = false
    @State private var lastProgressPublishedAt = Date.distantPast

    private var currentEpisode: Episode? {
        guard let context = seriesContext else { return nil }
        let id = currentEpisodeID ?? context.initialEpisodeID
        return context.episodes.first(where: { $0.id == id })
    }
    private var effectiveTitle: String { currentEpisode?.title ?? title }
    private var effectiveURLString: String { currentEpisode?.url ?? urlString }
    private var progressContentID: String? { currentEpisode?.id ?? contentID }
    private var progressKind: TVPlaybackContentKind { currentEpisode == nil ? .vod : .episode }
    private var originalURL: URL? {
        guard !effectiveURLString.isEmpty else { return nil }
        return URL(string: effectiveURLString)
    }

    private var isTransportStream: Bool {
        originalURL?.pathExtension.lowercased() == "ts"
    }

    /// Xtream live URLs commonly end in `.ts`. tvOS/AVPlayer is much happier
    /// with HLS, so try the equivalent `.m3u8` URL first. If the provider does
    /// not expose HLS, GhostStream retries the original URL before selecting the
    /// compatibility engine.
    private func nativePreferredURL(from original: URL) -> URL {
        let absolute = original.absoluteString
        if absolute.lowercased().hasSuffix(".ts") {
            let hls = String(absolute.dropLast(3)) + ".m3u8"
            return URL(string: hls) ?? original
        }
        return original
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if episodeSwitchInProgress {
                VStack(spacing: 18) {
                    ProgressView()
                    Text("Loading episode…")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else if let originalURL {
                playbackSurface(originalURL: originalURL)
            } else {
                TVPlaybackMessage(
                    systemImage: "play.slash",
                    title: "Invalid stream",
                    message: "GhostStream could not create a playback URL."
                )
            }

            if chromeVisible,
               let epgChannelId, !epgChannelId.isEmpty,
               let now = epg.nowPlaying(channelId: epgChannelId) {
                VStack {
                    Spacer()
                    TVLiveEPGOverlay(
                        now: now,
                        next: epg.upcoming(channelId: epgChannelId, limit: 1).first
                    )
                    .padding(.horizontal, 70)
                    .padding(.bottom, 125)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .task(id: epgChannelId) {
            guard let epgChannelId,
                  let streamId = Int(epgChannelId),
                  let source = store.activeSource else { return }
            await epg.ensureProviderEPG(streamId: streamId, source: source)
        }
        .navigationTitle("")
        .onAppear {
            if currentEpisodeID == nil { currentEpisodeID = seriesContext?.initialEpisodeID }
            revealPlayerChrome()
        }
        .onChange(of: currentTime) { _ in
            restoreProgressIfNeeded()
            if Date().timeIntervalSince(lastProgressPublishedAt) >= 10 {
                publishProgress(force: false)
            }
        }
        .onChange(of: duration) { _ in
            restoreProgressIfNeeded()
        }
        .onChange(of: playbackEndedToken) { _ in
            publishProgress(force: true, completedOverride: true)
        }
        .onDisappear {
            chromeHideWorkItem?.cancel()
            chromeHideWorkItem = nil
            publishProgress(force: true)
        }
        .onMoveCommand(perform: { _ in
            revealPlayerChrome()
        })
        .onPlayPauseCommand {
            revealPlayerChrome(delay: compatibilityPlaying ? 8 : 5)
        }
    }

    private func tvOrderedEpisodes() -> [Episode] { seriesContext?.episodes.sorted { ($0.season,$0.episodeNum) < ($1.season,$1.episodeNum) } ?? [] }

    private func revealPlayerChrome(delay: TimeInterval = 5) {
        chromeHideWorkItem?.cancel()
        chromeHideWorkItem = nil
        withAnimation(.easeInOut(duration: 0.20)) {
            chromeVisible = true
        }

        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.20)) {
                chromeVisible = false
            }
        }
        chromeHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    private func tvAdjacent(_ offset: Int) {
        guard !episodeSwitchInProgress else { return }
        let list = tvOrderedEpisodes()
        guard let id = currentEpisode?.id,
              let index = list.firstIndex(where: { $0.id == id }),
              list.indices.contains(index + offset) else { return }
        tvSwitch(list[index + offset])
    }

    private func tvSwitch(_ episode: Episode) {
        guard !episodeSwitchInProgress, episode.id != currentEpisode?.id else { return }

        // Persist the old episode before removing its decoder surface.
        publishProgress(force: true)

        // Fully remove the old AVKit/VLC surface before installing the next
        // episode. tvOS focus/video decoders can otherwise still be releasing
        // the previous surface when the new URL is assigned.
        episodeSwitchInProgress = true
        tvAudioTracks = []
        tvSubtitleTracks = []
        tvSelectedAudio = nil
        tvSelectedSubtitle = nil
        compatibilityPlaying = true
        useCompatibilityEngine = false
        tryOriginalNativeURL = false
        nativeAttemptsExhausted = false
        playbackError = nil

        revealPlayerChrome(delay: 8)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            currentEpisodeID = episode.id
            currentTime = 0
            duration = 0
            requestedPosition = nil
            didRestoreProgress = false
            lastProgressPublishedAt = .distantPast
            episodeSwitchInProgress = false
            revealPlayerChrome(delay: 8)
        }
    }

    private func restoreProgressIfNeeded() {
        guard !didRestoreProgress,
              duration > 30,
              let sourceID = store.activeSourceID,
              let contentID = progressContentID else { return }

        didRestoreProgress = true
        guard let saved = playbackProgress.records.first(where: {
            $0.sourceID == sourceID &&
            $0.contentKind == progressKind &&
            $0.contentID == contentID &&
            !$0.completed
        }), saved.positionSeconds > 10,
           saved.durationSeconds > 0,
           saved.positionSeconds < saved.durationSeconds * 0.95 else {
            return
        }

        requestedPosition = min(max(saved.positionSeconds / max(duration, saved.durationSeconds), 0), 0.94)
    }

    private func publishProgress(
        force: Bool,
        completedOverride: Bool? = nil
    ) {
        guard let sourceID = store.activeSourceID,
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
            contentKind: progressKind,
            contentID: contentID,
            title: effectiveTitle,
            seriesID: seriesContext?.seriesID,
            positionSeconds: completed ? duration : currentTime,
            durationSeconds: duration,
            completed: completed,
            updatedAt: now
        )
        lastProgressPublishedAt = now

        Task {
            try? await TVSyncService.shared.push(record)
        }
    }

    @ViewBuilder
    private func playbackSurface(originalURL: URL) -> some View {
        #if canImport(TVVLCKit)
        if useCompatibilityEngine || isTransportStream {
            ZStack(alignment: .bottom) {
                TVCompatibilityPlayer(
                    url: originalURL,
                    isPlaying: $compatibilityPlaying,
                    currentTime: $currentTime,
                    duration: $duration,
                    requestedPosition: $requestedPosition,
                    playbackEndedToken: $playbackEndedToken,
                    playbackCommand: compatibilityCommand,
                    audioTracks: $tvAudioTracks, subtitleTracks: $tvSubtitleTracks,
                    selectedAudioTrack: tvSelectedAudio, selectedSubtitleTrack: tvSelectedSubtitle,
                    trackCommand: tvTrackCommand
                )
                .id("compatibility-\(effectiveURLString)")
                .ignoresSafeArea()

                if chromeVisible {
                    HStack(spacing: 28) {
                    Button {
                        compatibilityCommand += 1
                    } label: {
                        Label(
                            compatibilityPlaying ? "Pause" : "Play",
                            systemImage: compatibilityPlaying ? "pause.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TVTheme.accent)

                    Spacer()
                    if #available(tvOS 17.0, *) {
                        Menu {
                            Menu("Audio") {
                                ForEach(tvAudioTracks) { track in
                                    Button(track.name) {
                                        tvSelectedAudio = track.id
                                        tvTrackCommand += 1
                                    }
                                }
                            }

                            Menu("Subtitles") {
                                Button("Off") {
                                    tvSelectedSubtitle = -1
                                    tvTrackCommand += 1
                                }
                                ForEach(tvSubtitleTracks) { track in
                                    Button(track.name) {
                                        tvSelectedSubtitle = track.id
                                        tvTrackCommand += 1
                                    }
                                }
                            }
                        } label: {
                            Label("Audio / Subtitles", systemImage: "captions.bubble")
                        }
                    } else {
                        Button { } label: {
                            Label("Audio / Subtitles", systemImage: "captions.bubble")
                        }
                        .disabled(true)
                    }

                    if let context = seriesContext {
                        Button { tvAdjacent(-1) } label: {
                            Label("Previous Episode", systemImage: "backward.end.fill")
                        }
                        .disabled(episodeSwitchInProgress)

                        if #available(tvOS 17.0, *) {
                            Menu {
                                ForEach(
                                    Array(Set(context.episodes.map(\.season))).sorted(),
                                    id: \.self
                                ) { season in
                                    Menu("Season \(season)") {
                                        ForEach(context.episodes.filter { $0.season == season }) { episode in
                                            Button("E\(episode.episodeNum) \(episode.title)") {
                                                tvSwitch(episode)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label("Season / Episode", systemImage: "list.bullet.rectangle")
                            }
                        } else {
                            Button { } label: {
                                Label("Season / Episode", systemImage: "list.bullet.rectangle")
                            }
                            .disabled(true)
                        }

                        Button { tvAdjacent(1) } label: {
                            Label("Next Episode", systemImage: "forward.end.fill")
                        }
                        .disabled(episodeSwitchInProgress)
                    }
                }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 70)
                    .padding(.vertical, 32)
                    .background(.black.opacity(0.62))
                    .transition(.opacity)
                }
            }
        } else {
            nativeSurface(originalURL: originalURL)
        }
        #else
        nativeSurface(originalURL: originalURL)
        #endif
    }

    @ViewBuilder
    private func nativeSurface(originalURL: URL) -> some View {
        if let playbackError, nativeAttemptsExhausted {
            TVPlaybackMessage(
                systemImage: "play.slash.fill",
                title: "Stream format not supported",
                message: playbackError + "\n\nGhostStream tried both native and compatibility playback for this stream."
            )
        } else {
            let candidate = tryOriginalNativeURL ? originalURL : nativePreferredURL(from: originalURL)
            TVNativePlayerController(
                url: candidate,
                currentTime: $currentTime,
                duration: $duration,
                requestedPosition: $requestedPosition,
                playbackEndedToken: $playbackEndedToken
            ) { message in
                DispatchQueue.main.async {
                    playbackError = message

                    // First failure may only mean the provider does not expose
                    // a matching HLS endpoint. Retry the original stream once.
                    if !tryOriginalNativeURL,
                       nativePreferredURL(from: originalURL) != originalURL {
                        tryOriginalNativeURL = true
                        return
                    }

                    nativeAttemptsExhausted = true
                    #if canImport(TVVLCKit)
                    useCompatibilityEngine = true
                    compatibilityPlaying = true
                    #endif
                }
            }
            .id("native-\(candidate.absoluteString)")
            .ignoresSafeArea()
        }
    }
}

private struct TVLiveEPGOverlay: View {
    let now: EPGProgramme
    let next: EPGProgramme?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("NOW PLAYING", systemImage: "calendar")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(TVTheme.accentBright)
                Spacer()
                Text(timeRange(now))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))
            }
            Text(now.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            TVLiveEPGProgress(start: now.start, stop: now.stop)
            if let next {
                Divider().overlay(Color.white.opacity(0.10))
                HStack(spacing: 12) {
                    Text("NEXT")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(TVTheme.muted)
                    Text(next.title)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)
                    Spacer()
                    Text(timeRange(next))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(TVTheme.muted)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .frame(maxWidth: 900)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(TVTheme.accent.opacity(0.34), lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeRange(_ programme: EPGProgramme) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: programme.start)) - \(f.string(from: programme.stop))"
    }
}

private struct TVPlaybackMessage: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 68, weight: .semibold))
                .foregroundStyle(TVTheme.accent)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(TVTheme.muted)
                .frame(maxWidth: 900)
        }
        .padding(60)
    }
}

/// Native tvOS player with AVKit controls plus reliable failure reporting.
/// It keeps the remote-native playback UI while allowing GhostStream to retry
/// another URL or select the compatibility engine when AVPlayer rejects a codec.
private struct TVNativePlayerController: UIViewControllerRepresentable {
    let url: URL
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var requestedPosition: Double?
    @Binding var playbackEndedToken: Int
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        // AVKit installs focus-control constraints with 95pt side insets. If
        // controls are enabled while SwiftUI is still presenting this view at
        // width 0, tvOS logs an unsatisfiable-constraints recovery. Defer the
        // controls until the controller is actually onscreen and wide enough.
        controller.showsPlaybackControls = false
        context.coordinator.attach(controller: controller, url: url)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.parent = self
        let coordinator = context.coordinator
        let nextURL = url
        let seekPosition = requestedPosition
        DispatchQueue.main.async {
            coordinator.update(controller: controller, url: nextURL)
            if let seekPosition {
                coordinator.seek(to: seekPosition)
                coordinator.parent.requestedPosition = nil
            }
        }
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject {
        var parent: TVNativePlayerController
        private let player = AVPlayer()
        private var currentURL: URL?
        private var itemStatusObservation: NSKeyValueObservation?
        private var failedToEndObserver: NSObjectProtocol?
        private var didEndObserver: NSObjectProtocol?
        private var timeObserver: Any?
        private var readinessWorkItem: DispatchWorkItem?
        private var controlsActivationWorkItem: DispatchWorkItem?
        private var failureDelivered = false
        private var loadGeneration = 0

        init(parent: TVNativePlayerController) {
            self.parent = parent
            super.init()
        }

        func attach(controller: AVPlayerViewController, url: URL) {
            controller.player = player
            controller.showsPlaybackControls = false
            schedulePlaybackControls(on: controller)
            play(url: url)
        }

        func update(controller: AVPlayerViewController, url: URL) {
            if controller.player !== player { controller.player = player }
            if !controller.showsPlaybackControls { schedulePlaybackControls(on: controller) }
            guard currentURL != url else { return }
            play(url: url)
        }

        private func schedulePlaybackControls(on controller: AVPlayerViewController, attempt: Int = 0) {
            guard !controller.showsPlaybackControls else { return }
            controlsActivationWorkItem?.cancel()

            let work = DispatchWorkItem { [weak self, weak controller] in
                guard let self, let controller else { return }
                if controller.viewIfLoaded?.window != nil,
                   controller.view.bounds.width >= 200 {
                    controller.showsPlaybackControls = true
                    self.controlsActivationWorkItem = nil
                } else if attempt < 40 {
                    self.schedulePlaybackControls(on: controller, attempt: attempt + 1)
                }
            }
            controlsActivationWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }

        private func play(url: URL) {
            cleanupObservers()
            currentURL = url
            failureDelivered = false
            loadGeneration += 1
            let generation = loadGeneration
            player.pause()
            player.replaceCurrentItem(with: nil)

            let asset = AVURLAsset(url: url)

            // Load the fields AVKit's Apple TV information panel requests before
            // exposing the item. This also gives us an early isPlayable signal.
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    let playable = try await asset.load(.isPlayable)
                    _ = try? await asset.load(.commonMetadata)
                    _ = try? await asset.load(.duration)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard generation == self.loadGeneration, self.currentURL == url else { return }
                        guard playable else {
                            self.failNative("Apple TV reported that this stream is not natively playable.")
                            return
                        }
                        self.install(asset: asset)
                    }
                } catch {
                    await MainActor.run {
                        guard generation == self.loadGeneration, self.currentURL == url else { return }
                        // Some live providers do not expose asset properties
                        // correctly. Install the item anyway and let AVPlayer's
                        // status tell us definitively whether it can decode it.
                        self.install(asset: asset)
                    }
                }
            }
        }

        private func install(asset: AVURLAsset) {
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 8
            item.preferredPeakBitRate = 12_000_000
            item.preferredMaximumResolution = CGSize(width: 1920, height: 1080)
            observe(item: item)
            player.replaceCurrentItem(with: item)
            player.automaticallyWaitsToMinimizeStalling = true
            player.actionAtItemEnd = .pause
            installTimelineObserver()
            player.play()

            let work = DispatchWorkItem { [weak self, weak item] in
                guard let self = self, let item = item else { return }
                if item.status != .readyToPlay {
                    self.failNative("Apple TV could not prepare this stream for playback.")
                }
            }
            readinessWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
        }

        private func observe(item: AVPlayerItem) {
            itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                guard let self = self else { return }
                switch item.status {
                case .readyToPlay:
                    self.readinessWorkItem?.cancel()
                case .failed:
                    self.failNative(item.error?.localizedDescription ?? "Apple TV rejected this stream format.")
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }

            failedToEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] note in
                let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                self?.failNative(error?.localizedDescription ?? "Playback failed.")
            }

            didEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.publishTimeline()
                self.parent.playbackEndedToken += 1
            }
        }

        private func installTimelineObserver() {
            if let timeObserver {
                player.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 1, preferredTimescale: 600),
                queue: .main
            ) { [weak self] _ in
                self?.publishTimeline()
            }
        }

        private func publishTimeline() {
            let current = CMTimeGetSeconds(player.currentTime())
            let total = player.currentItem.map { CMTimeGetSeconds($0.duration) } ?? 0
            if current.isFinite, current >= 0 {
                parent.currentTime = current
            }
            if total.isFinite, total > 0 {
                parent.duration = total
            }
        }

        func seek(to fraction: Double) {
            guard fraction.isFinite,
                  let item = player.currentItem else { return }
            let total = CMTimeGetSeconds(item.duration)
            guard total.isFinite, total > 0 else { return }
            let bounded = min(max(fraction, 0), 1)
            player.seek(
                to: CMTime(seconds: total * bounded, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
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
            loadGeneration += 1
            controlsActivationWorkItem?.cancel()
            controlsActivationWorkItem = nil
            player.pause()
            player.replaceCurrentItem(with: nil)
            currentURL = nil
            cleanupObservers()
        }

        private func cleanupObservers() {
            readinessWorkItem?.cancel()
            readinessWorkItem = nil
            itemStatusObservation = nil
            if let timeObserver {
                player.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
            if let failedToEndObserver {
                NotificationCenter.default.removeObserver(failedToEndObserver)
                self.failedToEndObserver = nil
            }
            if let didEndObserver {
                NotificationCenter.default.removeObserver(didEndObserver)
                self.didEndObserver = nil
            }
        }
    }
}

private struct TVMediaTrack: Identifiable, Hashable { let id: Int; let name: String }

#if canImport(TVVLCKit)
/// Embedded tvOS compatibility playback. No third-party branding is exposed in
/// the GhostStream interface; the framework is only used when AVPlayer cannot
/// decode the provider's stream.
private struct TVCompatibilityPlayer: UIViewRepresentable {
    let url: URL
    @Binding var isPlaying: Bool
    let playbackCommand: Int
    @Binding var audioTracks: [TVMediaTrack]
    @Binding var subtitleTracks: [TVMediaTrack]
    let selectedAudioTrack: Int?
    let selectedSubtitleTrack: Int?
    let trackCommand: Int

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        context.coordinator.attach(to: view, url: url)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        let coordinator = context.coordinator
        let nextURL = url
        let command = playbackCommand
        DispatchQueue.main.async {
            coordinator.update(url: nextURL, drawable: uiView)
            coordinator.handlePlaybackCommand(command)
            coordinator.handleTrackCommand(self.trackCommand)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, VLCMediaPlayerDelegate {
        var parent: TVCompatibilityPlayer
        private let mediaPlayer = VLCMediaPlayer()
        private var currentURL: URL?
        private weak var currentDrawable: UIView?
        private var lastPlaybackCommand = 0
        private var lastTrackCommand = 0
        private var isStopped = false

        init(parent: TVCompatibilityPlayer) {
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
            // Episode URL changes are represented by a brand-new player view.
            // Do not retarget an active VLCMediaPlayer in-place.
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
                "network-caching": 4000,
                "live-caching": 4000,
                "file-caching": 2000,
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
            if mediaPlayer.isPlaying { mediaPlayer.pause() }
            else { mediaPlayer.play() }
            publishState()
        }

        func mediaPlayerStateChanged(_ aNotification: Notification) {
            guard !isStopped else { return }
            publishTracks()
            publishState()
        }

        func handleTrackCommand(_ command: Int) {
            guard !isStopped, command != lastTrackCommand else { return }; lastTrackCommand=command
            if let id=parent.selectedAudioTrack { mediaPlayer.currentAudioTrackIndex=Int32(id) }
            if let id=parent.selectedSubtitleTrack { mediaPlayer.currentVideoSubTitleIndex=Int32(id) }
        }
        private func publishTracks() {
            guard !isStopped else { return }
            let an=mediaPlayer.audioTrackNames as? [String] ?? []; let ai=mediaPlayer.audioTrackIndexes as? [NSNumber] ?? []
            let sn=mediaPlayer.videoSubTitlesNames as? [String] ?? []; let si=mediaPlayer.videoSubTitlesIndexes as? [NSNumber] ?? []
            let a=zip(ai,an).map{TVMediaTrack(id:$0.0.intValue,name:$0.1)}; let st=zip(si,sn).filter{$0.0.intValue>=0}.map{TVMediaTrack(id:$0.0.intValue,name:$0.1)}
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isStopped else { return }
                self.parent.audioTracks = a
                self.parent.subtitleTracks = st
            }
        }

        private func publishState() {
            guard !isStopped else { return }
            let playing = mediaPlayer.isPlaying
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isStopped else { return }
                self.parent.isPlaying = playing
            }
        }

        func stop() {
            guard !isStopped else { return }
            // Mark stopped first so any already-queued VLC delegate work becomes
            // a no-op while the old episode decoder is released.
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

private enum TVSourceFocus: Hashable {
    case mode
    case name
    case server
    case username
    case password
    case playlist
    case connect
    case saved(UUID)
}

private struct TVSourceSetupView: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    let onConnected: (() -> Void)?
    let onClose: (() -> Void)?

    @State private var mode = 0
    @State private var name = ""
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var playlist = ""
    @State private var error: String?
    @State private var isSaving = false
    @FocusState private var sourceFocus: TVSourceFocus?

    init(onConnected: (() -> Void)? = nil, onClose: (() -> Void)? = nil) {
        self.onConnected = onConnected
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            TVBackground(showHero: false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    HStack(spacing: 20) {
                        Image("APKBrandLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 86, height: 86)
                            .clipShape(RoundedRectangle(cornerRadius: 20))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("SOURCES")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Connect a provider login or M3U playlist")
                                .font(.headline)
                                .foregroundStyle(TVTheme.muted)
                        }

                        Spacer()

                        if onClose != nil {
                            Button { onClose?() } label: {
                                Label("Close", systemImage: "xmark")
                            }
                            .buttonStyle(TVGhostFocusStyle())
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.10))

                    Picker("Source Type", selection: $mode) {
                        Text("Provider Login").tag(0)
                        Text("M3U URL").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .focused($sourceFocus, equals: .mode)

                    VStack(spacing: 14) {
                        TextField("Display name", text: $name)
                            .tvInputStyle()
                            .focused($sourceFocus, equals: .name)

                        if mode == 0 {
                            TextField("Server URL (https://host:port)", text: $server)
                                .tvInputStyle()
                                .focused($sourceFocus, equals: .server)
                            HStack(spacing: 14) {
                                TextField("Username", text: $username)
                                    .tvInputStyle()
                                    .focused($sourceFocus, equals: .username)
                                SecureField("Password", text: $password)
                                    .tvInputStyle()
                                    .focused($sourceFocus, equals: .password)
                            }
                        } else {
                            TextField("M3U playlist URL", text: $playlist)
                                .tvInputStyle()
                                .focused($sourceFocus, equals: .playlist)
                        }
                    }

                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        Button { Task { await save() } } label: {
                            HStack(spacing: 12) {
                                if isSaving { ProgressView().tint(.black) }
                                Text(isSaving ? "CONNECTING…" : "CONNECT SOURCE")
                                    .font(.headline.weight(.bold))
                                    .tracking(1.2)
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 14)
                            .background(TVTheme.accent, in: Capsule())
                        }
                        .buttonStyle(TVGhostFocusStyle())
                        .focused($sourceFocus, equals: .connect)
                        .disabled(isSaving)

                        Spacer()
                    }

                    if !store.sources.isEmpty {
                        Divider().overlay(Color.white.opacity(0.10))
                        VStack(alignment: .leading, spacing: 14) {
                            Text("SAVED SOURCES")
                                .font(.headline.weight(.bold))
                                .tracking(2.4)
                                .foregroundStyle(TVTheme.accentBright)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                                ForEach(store.sources) { source in
                                    Button {
                                        Task { await activateSaved(source) }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: source.kind == .xtream ? "server.rack" : "list.bullet.rectangle")
                                                .foregroundStyle(TVTheme.accentBright)
                                            Text(source.name)
                                                .lineLimit(1)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(TVTheme.muted)
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 15)
                                        .frame(maxWidth: .infinity)
                                        .background(TVTheme.cardGradient, in: RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(TVTheme.border, lineWidth: 1))
                                    }
                                    .buttonStyle(TVGhostFocusStyle())
                                    .focused($sourceFocus, equals: .saved(source.id))
                                }
                            }
                        }
                    }

                    Text("GhostStream does not provide channels, movies, subscriptions, or playlists.")
                        .font(.footnote)
                        .foregroundStyle(TVTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(38)
                .frame(maxWidth: 1040)
                .background(TVTheme.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 28))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(TVTheme.accent.opacity(0.28), lineWidth: 1))
                .padding(.horizontal, 70)
                .padding(.vertical, 48)
            }
        }
        .focusSection()
        .onAppear {
            if sourceFocus == nil { sourceFocus = .mode }
        }
    }

    private func activateSaved(_ source: Source) async {
        error = nil
        isSaving = true
        defer { isSaving = false }

        // Load and validate first. Activating before the load completes makes
        // TVRootView start a second load behind this sheet and is the reason
        // the old source screen could remain visibly stuck on top.
        await library.load(source: source)
        guard library.loadedSourceID == source.id else {
            error = library.errorMessage ?? "Could not reload this source."
            return
        }
        store.setActive(source)
        onConnected?()
    }

    private func save() async {
        error = nil
        isSaving = true
        defer { isSaving = false }

        let display = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (mode == 0 ? "Provider" : "Playlist")
            : name.trimmingCharacters(in: .whitespacesAndNewlines)

        let source: Source
        if mode == 0 {
            let trimmedServer = server.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedServer.isEmpty, !trimmedUser.isEmpty, !password.isEmpty else {
                error = "Enter server, username, and password."
                return
            }
            source = Source(name: display, kind: .xtream, serverURL: trimmedServer, username: trimmedUser, password: password)
        } else {
            let trimmedPlaylist = playlist.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmedPlaylist), url.scheme != nil else {
                error = "Enter a valid playlist URL including http:// or https://."
                return
            }
            source = Source(name: display, kind: .m3uURL, m3uURL: trimmedPlaylist)
        }

        // Fetch before activation so Apple TV never lands on an empty home
        // screen just because the active-source task missed its reload.
        await library.load(source: source)
        guard library.loadedSourceID == source.id else {
            error = library.errorMessage ?? "The source connected, but no media data could be fetched."
            return
        }

        store.add(source)
        store.setActive(source)
        onConnected?()
    }
}
