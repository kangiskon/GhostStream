import SwiftUI
import UIKit
import ImageIO

enum GhostPrimarySection: Int, CaseIterable, Hashable {
    case home, live, movies, series, sources

    var title: String {
        switch self {
        case .home: return "Home"
        case .live: return "Live TV"
        case .movies: return "Movies"
        case .series: return "Series"
        case .sources: return "Sources"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .live: return "tv.fill"
        case .movies: return "film.fill"
        case .series: return "movieclapper"
        case .sources: return "externaldrive.fill"
        }
    }
}

/// Unified GhostStream shell: touch-native on iPhone, TV-style top navigation on iPad.
struct RootTabView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var epg: EPGService

    var body: some View {
        Group {
            if accountStore.isSignedIn || !store.sources.isEmpty {
                GhostStreamShellView()
            } else {
                AuthView()
            }
        }
        .task(id: store.activeSourceID) {
            await reloadActiveSource()
        }
    }

    private func reloadActiveSource() async {
        guard let source = store.activeSource else {
            library.reset()
            epg.clear()
            return
        }
        if library.loadedSourceID != source.id {
            await library.load(source: source)
        }
        if epg.programmes.isEmpty && !epg.isLoading {
            await epg.load(for: source)
        }
    }
}

struct GhostTopNavigation: View {
    @Binding var selection: GhostPrimarySection
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 10) {
                Image("GhostBrandExact")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                Text("GHOSTSTREAM")
                    .font(.headline.weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(.white)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GhostPrimarySection.allCases, id: \.self) { section in
                        Button {
                            selection = section
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: section.icon)
                                Text(section.title)
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(selection == section ? .white : .white.opacity(0.68))
                            .padding(.horizontal, 15)
                            .frame(height: 44)
                            .background(
                                Capsule().fill(selection == section ? Theme.accent.opacity(0.28) : Theme.card.opacity(0.78))
                            )
                            .overlay(
                                Capsule().stroke(selection == section ? Theme.accentBright : Theme.border, lineWidth: selection == section ? 1.6 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 8)
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accentBright)
                    .frame(width: 44, height: 44)
                    .background(Theme.card, in: Circle())
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.background.opacity(0.97))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

// MARK: - Unified Home

private struct GhostHomeView: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    @Binding var selection: GhostPrimarySection
    let onSettings: () -> Void

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let safeWidth = max(proxy.size.width - proxy.safeAreaInsets.leading - proxy.safeAreaInsets.trailing, 1)
                let isPadLike = UIDevice.current.userInterfaceIdiom == .pad
                let horizontalInset: CGFloat = isPadLike ? 34 : 14
                let contentWidth = max(1, safeWidth - horizontalInset * 2)

                ZStack {
                    GhostScreenBackground(showHero: false)
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: isPadLike ? 26 : 18) {
                            if !isPadLike {
                                GhostBrandHeader(
                                    subtitle: store.activeSource?.name.uppercased() ?? "STREAM BEYOND LIMITS",
                                    trailingIcon: "gearshape.fill",
                                    trailingAction: onSettings
                                )
                            }

                            hero(isPadLike: isPadLike)

                            if let notice = library.refreshNotice {
                                Label(notice, systemImage: "arrow.clockwise")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accentBright)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                                    .accessibilityLabel(notice)
                            }

                            if store.activeSource == nil {
                                EmptySourcePrompt().frame(minHeight: isPadLike ? 300 : 240)
                            } else {
                                quickGrid(isPadLike: isPadLike)
                                if !library.channels.isEmpty { liveRail }
                                if !library.movies.isEmpty { movieRail }
                                if !library.series.isEmpty { seriesRail }
                            }
                        }
                        .frame(width: contentWidth)
                        .padding(.horizontal, horizontalInset)
                        .padding(.vertical, isPadLike ? 20 : 10)
                        .padding(.bottom, max(28, proxy.safeAreaInsets.bottom + 18))
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func hero(isPadLike: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image("GhostHomeHero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: isPadLike ? 390 : 245)
                .clipped()

            LinearGradient(
                colors: [.clear, Theme.background.opacity(0.18), Theme.background.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )

            Theme.heroGlow

            VStack(alignment: .leading, spacing: 12) {
                Text("GHOSTSTREAM")
                    .font(.system(size: isPadLike ? 42 : 28, weight: .black))
                    .tracking(2.0)
                    .foregroundStyle(.white)
                Text(store.activeSource?.name ?? "Entertainment without limits")
                    .font(isPadLike ? .title3.weight(.medium) : .subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Button("WATCH LIVE") { selection = .live }
                        .buttonStyle(GhostHeroButtonStyle(prominent: true))
                    Button("BROWSE LIBRARY") { selection = .movies }
                        .buttonStyle(GhostHeroButtonStyle(prominent: false))
                }
            }
            .padding(isPadLike ? 30 : 18)
        }
        .clipShape(RoundedRectangle(cornerRadius: isPadLike ? 24 : 18))
        .overlay(RoundedRectangle(cornerRadius: isPadLike ? 24 : 18).stroke(Theme.border, lineWidth: 1))
    }

    private func quickGrid(isPadLike: Bool) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: isPadLike ? 16 : 10), count: isPadLike ? 4 : 2),
            spacing: isPadLike ? 16 : 10
        ) {
            homeTile("LIVE TV", icon: "tv.fill", count: library.channels.count, section: .live)
            homeTile("MOVIES", icon: "film.fill", count: library.movies.count, section: .movies)
            homeTile("SERIES", icon: "movieclapper", count: library.series.count, section: .series)
            homeTile("SOURCES", icon: "externaldrive.fill", count: store.sources.count, section: .sources)
        }
    }

    private func homeTile(_ title: String, icon: String, count: Int, section: GhostPrimarySection) -> some View {
        Button { selection = section } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.accentBright)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(.white)
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 126)
            .background(Theme.cardGradient, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var liveRail: some View {
        GhostMediaRail(title: "LIVE TV", tabAction: { selection = .live }) {
            ForEach(Array(library.channels.prefix(10))) { channel in
                VStack(alignment: .leading, spacing: 6) {
                    LogoThumb(urlString: channel.logo, fallbackSystem: "tv.fill")
                        .frame(width: 84, height: 84)
                    Text(channel.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .frame(width: 120, alignment: .leading)
                }
            }
        }
    }

    private var movieRail: some View {
        GhostMediaRail(title: "MOVIES", tabAction: { selection = .movies }) {
            ForEach(Array(library.movies.prefix(12))) { movie in
                NavigationLink {
                    PlayerView(title: movie.name, urlString: movie.url ?? "", kind: .vod, contentID: String(movie.id))
                } label: {
                    GhostPosterCard(title: movie.name, imageURL: movie.icon)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var seriesRail: some View {
        GhostMediaRail(title: "SERIES", tabAction: { selection = .series }) {
            ForEach(Array(library.series.prefix(12))) { show in
                NavigationLink { SeriesDetailView(series: show) } label: {
                    GhostPosterCard(title: show.name, imageURL: show.cover)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct GhostHeroButtonStyle: ButtonStyle {
    let prominent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.black))
            .tracking(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(prominent ? Theme.accent : Theme.card.opacity(0.92), in: Capsule())
            .overlay(Capsule().stroke(prominent ? Theme.accentBright : Theme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

// MARK: - Shared concept components

struct GhostScreenBackground: View {
    var showHero: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()
            LinearGradient(
                colors: [Theme.accent.opacity(0.07), .black.opacity(0.35)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            if showHero {
                GeometryReader { geo in
                    Image("GhostHomeHero")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: min(max(geo.size.height * 0.28, 210), 360))
                        .clipped()
                }
                    .opacity(0.48)
                    .mask(
                        LinearGradient(colors: [.white, .white.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                    )
                    .allowsHitTesting(false)
            }
        }
    }
}

struct GhostBrandHeader: View {
    let subtitle: String
    var trailingIcon: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image("GhostBrandExact")
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.accent.opacity(0.55), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Image("GhostWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 165, height: 38, alignment: .leading)
                    .clipped()

                Text(subtitle)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(Theme.accent.opacity(0.82))
                    .lineLimit(1)
            }

            Spacer()

            if let trailingIcon, let trailingAction {
                Button(action: trailingAction) {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 38, height: 38)
                        .background(Theme.card.opacity(0.92), in: Circle())
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct GhostPageHeader: View {
    let title: String
    var showSearchIcon: Bool = true

    var body: some View {
        HStack {
            Image(systemName: "chevron.left").opacity(0)
                .frame(width: 30)
            Spacer()
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: showSearchIcon ? "magnifyingglass" : "circle")
                .foregroundStyle(showSearchIcon ? Theme.accent : .clear)
                .frame(width: 30)
        }
        .padding(.vertical, 6)
    }
}

struct GhostSearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.70))
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .foregroundStyle(.white)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 42)
        .background(Theme.card2.opacity(0.95), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}

struct GhostSegmentedChips: View {
    let titles: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(titles.indices, id: \.self) { index in
                Button {
                    selectedIndex = index
                } label: {
                    Text(titles[index])
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selectedIndex == index ? Color.black : Color.white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedIndex == index ? Theme.accent : Theme.card, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct GhostPosterCard: View {
    let title: String
    let imageURL: String?
    var width: CGFloat = 105

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Theme.cardGradient)
                placeholder
                if let imageURL, let url = URL(string: imageURL) {
                    GhostCachedPosterImage(url: url, targetWidth: width)
                }
            }
            .frame(width: width, height: width * 1.45)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.26), lineWidth: 1))

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)
        }
    }

    private var placeholder: some View {
        ZStack {
            Image("GhostBrandExact")
                .resizable().scaledToFill().opacity(0.22)
            Image(systemName: "play.rectangle.fill")
                .font(.title2)
                .foregroundStyle(Theme.accent.opacity(0.75))
        }
    }
}

struct GhostMediaRail<Content: View>: View {
    let title: String
    let tabAction: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.2)
                Spacer()
                Button("SEE ALL", action: tabAction)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) { content() }
            }
        }
    }
}


struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isFavorite ? Theme.accent : Color.white)
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.68), in: Circle())
                .overlay(Circle().stroke(isFavorite ? Theme.accent.opacity(0.75) : Color.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
    }
}

// MARK: - Cancelable, downsampled poster loading for iPhone and iPad

/// Image bytes are not persisted because artwork URLs from user providers can
/// include temporary tokens. The decoded thumbnails have a strict RAM budget.
actor GhostPosterMemoryCache {
    static let shared = GhostPosterMemoryCache()
    private let memory = NSCache<NSString, UIImage>()

    init() {
        memory.totalCostLimit = 48 * 1024 * 1024
        memory.countLimit = 180
    }

    func image(for url: URL, maxPixel: Int) async -> UIImage? {
        guard url.scheme == "http" || url.scheme == "https" else { return nil }
        let key = "\(url.absoluteString)|\(maxPixel)" as NSString
        if let thumbnail = memory.object(forKey: key) { return thumbnail }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled, data.count <= 8 * 1024 * 1024,
                  (response as? HTTPURLResponse).map({ 200...299 ~= $0.statusCode }) ?? true else { return nil }
            let thumbnail = await Task.detached(priority: .utility) { () -> UIImage? in
                let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
                guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else { return nil }
                let thumbOptions: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixel
                ]
                guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else { return nil }
                return UIImage(cgImage: cg)
            }.value
            guard !Task.isCancelled, let thumbnail else { return nil }
            memory.setObject(thumbnail, forKey: key,
                             cost: thumbnail.cgImage.map { $0.width * $0.height * 4 } ?? 0)
            return thumbnail
        } catch {
            return nil
        }
    }
}

struct GhostCachedPosterImage: View {
    let url: URL
    let targetWidth: CGFloat
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Color.clear
            }
        }
        .task(id: "\(url.absoluteString)|\(targetWidth)") {
            image = nil
            let pixel = max(180, min(900, Int(targetWidth * UIScreen.main.scale * 1.6)))
            image = await GhostPosterMemoryCache.shared.image(for: url, maxPixel: pixel)
        }
    }
}
