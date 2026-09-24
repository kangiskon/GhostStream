import SwiftUI

struct GhostLibraryHubView: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LIBRARY")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .tracking(2)
                            Text(store.activeSource?.name ?? "No source connected")
                                .foregroundStyle(Theme.muted)
                        }

                        LazyVGrid(columns: columns, spacing: 12) {
                            NavigationLink { LiveView() } label: {
                                LibraryCommandTile(title: "Live TV", detail: "(library.channels.count) channels", icon: "tv.fill")
                            }
                            NavigationLink { MoviesView() } label: {
                                LibraryCommandTile(title: "Movies", detail: "(library.movies.count) titles", icon: "film.fill")
                            }
                            NavigationLink { SeriesView() } label: {
                                LibraryCommandTile(title: "Series", detail: "(library.series.count) shows", icon: "rectangle.stack.fill")
                            }
                            NavigationLink { SearchView() } label: {
                                LibraryCommandTile(title: "Search", detail: "Across your source", icon: "magnifyingglass")
                            }
                            NavigationLink { LauncherView() } label: {
                                LibraryCommandTile(title: "Sources", detail: "(store.sources.count) saved", icon: "externaldrive.fill")
                            }
                        }

                        Text("GhostStream displays only media supplied by sources you add and are authorized to access.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 4)
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct LibraryCommandTile: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.accentBright)
                .frame(width: 46, height: 46)
                .background(Theme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 13))
            Spacer(minLength: 0)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 135, alignment: .leading)
        .padding(16)
        .background(Theme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
    }
}
