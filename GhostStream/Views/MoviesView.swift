import SwiftUI

struct MoviesView: View {
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
                        GhostPageHeader(title: "Movies")
                        GhostSearchField(text: $searchText, placeholder: "Search movies…")
                        GhostSegmentedChips(titles: ["ALL", "FAVORITES", "RECENT"], selectedIndex: $segment)

                        if store.activeSource == nil { EmptySourcePrompt() }
                        else if library.isLoading && library.movies.isEmpty { Spacer(); ProgressView("Loading movies…"); Spacer() }
                        else if library.movies.isEmpty { Spacer(); Text("No movies available.").foregroundStyle(Theme.muted); Spacer() }
                        else { movieGrid(availableWidth: contentWidth, isPadLike: isPadLike) }
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

    private var filteredMovies: [VODStream] {
        var base = library.movies
        if segment == 1, let sourceID = store.activeSourceID {
            base = base.filter { favorites.contains(sourceID: sourceID, kind: .vod, id: String($0.id)) }
        }
        if let selectedCategory { base = base.filter { $0.categoryId == selectedCategory.id } }
        if !searchText.isEmpty { base = base.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
        return base
    }

    private func loadMore() {
        visibleLimit += 48
    }

    private func isFavorite(_ movie: VODStream) -> Bool {
        guard let sourceID = store.activeSourceID else { return false }
        return favorites.contains(sourceID: sourceID, kind: .vod, id: String(movie.id))
    }

    private func toggleFavorite(_ movie: VODStream) {
        guard let sourceID = store.activeSourceID else { return }
        favorites.toggle(sourceID: sourceID, kind: .vod, id: String(movie.id))
    }

    private func movieGrid(availableWidth: CGFloat, isPadLike: Bool) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                let filtered = filteredMovies
                let page = Array(filtered.prefix(visibleLimit))
                if !library.movieCategories.isEmpty {
                    CategoryChips(categories: library.movieCategories, selection: $selectedCategory)
                }
                let phoneColumnCount = availableWidth >= 390 ? 3 : 2
                let padColumnCount = max(4, min(6, Int(availableWidth / 190)))
                let columnCount = isPadLike ? padColumnCount : phoneColumnCount
                let spacing: CGFloat = isPadLike ? 18 : 10
                let cardWidth = max(96, (availableWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnCount), spacing: isPadLike ? 22 : 14) {
                    ForEach(page) { movie in
                        ZStack(alignment: .topTrailing) {
                            NavigationLink {
                                PlayerView(title: movie.name, urlString: movie.url ?? "", kind: .vod, contentID: String(movie.id))
                            } label: {
                                GhostPosterCard(title: movie.name, imageURL: movie.icon, width: min(cardWidth, 180))
                            }
                            .buttonStyle(.plain)

                            FavoriteButton(isFavorite: isFavorite(movie)) {
                                toggleFavorite(movie)
                            }
                            .padding(6)
                        }
                        .onAppear {
                            if movie.id == page.last?.id && page.count < filtered.count {
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

struct PosterCard: View {
    let title: String
    let imageURL: String?
    var body: some View { GhostPosterCard(title: title, imageURL: imageURL, width: 104) }
}
