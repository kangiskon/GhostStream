import Foundation
import SwiftUI

struct SeriesView: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    @ObservedObject private var favorites = FavoriteStore.shared
    @State private var selectedCategory: Category?
    @State private var segment = 0
    @State private var searchText = ""
    @State private var visibleLimit = 48

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let safeWidth = max(proxy.size.width - proxy.safeAreaInsets.leading - proxy.safeAreaInsets.trailing, 1)
                let isPadLike = safeWidth >= 700
                let contentWidth = max(1, min(safeWidth - (isPadLike ? 56 : 24), isPadLike ? 1120 : 620))
                ZStack {
                    GhostScreenBackground().frame(width: proxy.size.width, height: proxy.size.height).clipped()
                    VStack(spacing: isPadLike ? 18 : 11) {
                        GhostPageHeader(title: "Series")
                        GhostSearchField(text: $searchText, placeholder: "Search series…")
                        GhostSegmentedChips(titles: ["ALL", "FAVORITES", "A–Z"], selectedIndex: $segment)

                        if store.activeSource == nil { EmptySourcePrompt() }
                        else if library.isLoading && library.series.isEmpty { Spacer(); ProgressView("Loading series…"); Spacer() }
                        else if library.series.isEmpty { Spacer(); Text("No series available.").foregroundStyle(Theme.muted); Spacer() }
                        else { seriesGrid(availableWidth: contentWidth, isPadLike: isPadLike) }
                    }
                    .frame(width: contentWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.top, isPadLike ? 12 : 4)
                }
            }
            .navigationBarHidden(true)
            .onChange(of: searchText) { _ in visibleLimit = 48 }
            .onChange(of: segment) { _ in visibleLimit = 48 }
            .onChange(of: selectedCategory) { _ in visibleLimit = 48 }
        }
    }

    private var filteredSeries: [Series] {
        var base = library.series
        if segment == 1, let sourceID = store.activeSourceID {
            base = base.filter { favorites.contains(sourceID: sourceID, kind: .series, id: String($0.id)) }
        }
        if let selectedCategory { base = base.filter { $0.categoryId == selectedCategory.id } }
        if !searchText.isEmpty { base = base.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
        return base
    }

    private func loadMore() {
        visibleLimit += 48
    }

    private func isFavorite(_ show: Series) -> Bool {
        guard let sourceID = store.activeSourceID else { return false }
        return favorites.contains(sourceID: sourceID, kind: .series, id: String(show.id))
    }

    private func toggleFavorite(_ show: Series) {
        guard let sourceID = store.activeSourceID else { return }
        favorites.toggle(sourceID: sourceID, kind: .series, id: String(show.id))
    }

    private func seriesGrid(availableWidth: CGFloat, isPadLike: Bool) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                let filtered = filteredSeries
                let page = Array(filtered.prefix(visibleLimit))
                if !library.seriesCategories.isEmpty { CategoryChips(categories: library.seriesCategories, selection: $selectedCategory) }
                let phoneColumnCount = availableWidth >= 390 ? 3 : 2
                let padColumnCount = max(4, min(6, Int(availableWidth / 190)))
                let columnCount = isPadLike ? padColumnCount : phoneColumnCount
                let spacing: CGFloat = isPadLike ? 18 : 10
                let cardWidth = max(96, (availableWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnCount), spacing: isPadLike ? 22 : 14) {
                    ForEach(page) { show in
                        ZStack(alignment: .topTrailing) {
                            NavigationLink { SeriesDetailView(series: show) } label: {
                                GhostPosterCard(title: show.name, imageURL: show.cover, width: min(cardWidth, 180))
                            }
                            .buttonStyle(.plain)

                            FavoriteButton(isFavorite: isFavorite(show)) {
                                toggleFavorite(show)
                            }
                            .padding(6)
                        }
                        .onAppear {
                            if show.id == page.last?.id && page.count < filtered.count {
                                loadMore()
                            }
                        }
                    }
                }
                .padding(.bottom, 18)
                if filtered.count > visibleLimit {
                    Button("Load more") {
                        loadMore()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

struct SeriesDetailView: View {
    let series: Series
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    @State private var episodes: [Episode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var episodesBySeason: [(season: Int, episodes: [Episode])] {
        let grouped = Dictionary(grouping: episodes, by: { $0.season })
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        ZStack {
            GhostScreenBackground(showHero: true)
            Group {
                if isLoading { ProgressView("Loading episodes…") }
                else if let errorMessage {
                    VStack(spacing: 12) {
                        ErrorState(message: errorMessage)
                        Button("Retry") { Task { await loadEpisodes() } }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                    }
                }
                else if episodes.isEmpty { Text("No episodes found.").foregroundStyle(Theme.muted) }
                else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top, spacing: 18) {
                                if let cover = series.cover, let url = URL(string: cover) {
                                    AsyncImage(url: url) { phase in
                                        if case .success(let image) = phase { image.resizable().scaledToFill() }
                                        else { Theme.card }
                                    }
                                    .frame(width: 160, height: 235)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                                }
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(series.name)
                                        .font(.title2.weight(.black))
                                        .foregroundStyle(.white)
                                    if let plot = series.plot, !plot.isEmpty {
                                        Text(plot)
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.muted)
                                            .lineLimit(8)
                                    }
                                    Text("\(episodes.count) EPISODES")
                                        .font(.caption.weight(.black))
                                        .tracking(1.1)
                                        .foregroundStyle(Theme.accentBright)
                                }
                                Spacer(minLength: 0)
                            }
                            ForEach(episodesBySeason, id: \.season) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("SEASON \(group.season)").font(.caption.bold()).tracking(1.2).foregroundStyle(Theme.accent)
                                    ForEach(group.episodes) { episode in
                                        NavigationLink {
                                            PlayerView(title: episode.title, urlString: episode.url ?? "", kind: .vod, contentID: episode.id, seriesContext: SeriesPlaybackContext(seriesID: series.id, seriesTitle: series.name, plot: series.plot, episodes: episodes, initialEpisodeID: episode.id))
                                        } label: {
                                            HStack(spacing: 12) {
                                                Text(String(format: "%02d", episode.episodeNum)).font(.caption.monospacedDigit()).foregroundStyle(Theme.accent)
                                                Text(episode.title).foregroundStyle(.white).lineLimit(1)
                                                Spacer(); Image(systemName: "play.circle.fill").foregroundStyle(Theme.accent)
                                            }
                                            .padding(12)
                                            .background(Theme.cardGradient, in: RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(14)
                    }
                }
            }
        }
        .navigationTitle(series.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEpisodes() }
    }

    private func loadEpisodes() async {
        guard episodes.isEmpty, !isLoading else { return }
        guard let source = store.activeSource, source.kind == .xtream,
              let server = source.serverURL, let user = source.username, let pass = source.password else {
            errorMessage = "Series playback requires a provider source."; return
        }
        errorMessage = nil
        isLoading = true; defer { isLoading = false }
        let client = XtreamClient(serverURL: library.resolvedProviderBaseURL ?? server,
                                  username: user, password: pass)
        do { episodes = try await client.seriesInfo(seriesId: series.id) }
        catch { errorMessage = error.localizedDescription }
    }
}
