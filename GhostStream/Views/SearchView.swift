import SwiftUI

/// Search across the currently loaded live channels, movies, and series.
struct SearchView: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel

    @State private var query = ""

    private var results: (channels: [Channel], movies: [VODStream], series: [Series]) {
        library.search(query)
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.activeSource == nil {
                    EmptySourcePrompt()
                } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Search channels, movies and series.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .background(Theme.background.ignoresSafeArea())
        }
        .searchable(text: $query, prompt: "Search")
    }

    @ViewBuilder
    private var resultsList: some View {
        let r = results
        if r.channels.isEmpty && r.movies.isEmpty && r.series.isEmpty {
            Text("No results for \"\(query)\"")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if !r.channels.isEmpty {
                    Section("Channels") {
                        ForEach(r.channels) { channel in
                            NavigationLink {
                                PlayerView(title: channel.name, urlString: channel.url, kind: .live, epgChannelId: channel.streamId.map(String.init))
                            } label: {
                                Label(channel.name, systemImage: "tv")
                            }
                            .listRowBackground(Theme.card)
                        }
                    }
                }
                if !r.movies.isEmpty {
                    Section("Movies") {
                        ForEach(r.movies) { movie in
                            NavigationLink {
                                PlayerView(title: movie.name, urlString: movie.url ?? "", kind: .vod)
                            } label: {
                                Label(movie.name, systemImage: "film")
                            }
                            .listRowBackground(Theme.card)
                        }
                    }
                }
                if !r.series.isEmpty {
                    Section("Series") {
                        ForEach(r.series) { show in
                            NavigationLink {
                                SeriesDetailView(series: show)
                            } label: {
                                Label(show.name, systemImage: "rectangle.stack")
                            }
                            .listRowBackground(Theme.card)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }
}
