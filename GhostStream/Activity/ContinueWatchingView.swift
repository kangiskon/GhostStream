import SwiftUI

struct ContinueWatchingView: View {
    @EnvironmentObject private var store: SourceStore
    @ObservedObject private var progress = PlaybackProgressStore.shared

    var limit: Int = 6

    private var visibleRecords: [PlaybackProgressRecord] {
        Array(
            progress.records
                .filter { record in
                    guard !record.completed,
                          record.durationSeconds > 30,
                          record.positionSeconds > 10,
                          record.positionSeconds / max(record.durationSeconds, 1) < 0.95,
                          store.sources.contains(where: { $0.id == record.sourceID }) else {
                        return false
                    }
                    return true
                }
                .prefix(limit)
        )
    }

    var body: some View {
        Group {
            if visibleRecords.isEmpty {
                HStack(spacing: 13) {
                    Image(systemName: "play.rectangle")
                        .font(.title3)
                        .foregroundStyle(Theme.accentBright)
                        .frame(width: 40, height: 40)
                        .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Nothing in progress yet")
                            .font(.subheadline.weight(.semibold))
                        Text("Continue Watching will appear here after you start a movie or episode.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(visibleRecords) { record in
                            NavigationLink {
                                ResumeContentDestination(record: record)
                            } label: {
                                ContinueWatchingCard(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .accessibilityLabel("Continue Watching")
    }
}

private struct ContinueWatchingCard: View {
    let record: PlaybackProgressRecord

    private var progressValue: Double {
        guard record.durationSeconds > 0 else { return 0 }
        return min(max(record.positionSeconds / record.durationSeconds, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardGradient)

                Image(systemName: record.contentKind == .episode ? "play.square.stack.fill" : "film.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.accentBright)

                VStack {
                    Spacer()
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15))
                            Capsule()
                                .fill(Theme.accentBright)
                                .frame(width: max(4, geometry.size.width * progressValue))
                        }
                    }
                    .frame(height: 5)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            }
            .frame(width: 190, height: 108)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))

            Text(record.title ?? (record.contentKind == .episode ? "Episode" : "Movie"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 190, alignment: .leading)

            HStack {
                Text(record.contentKind == .episode ? "EPISODE" : "MOVIE")
                Spacer()
                Text("(Int(progressValue * 100))%")
                    .monospacedDigit()
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Theme.muted)
            .frame(width: 190)
        }
    }
}

private struct ResumeContentDestination: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel

    let record: PlaybackProgressRecord

    @State private var movie: VODStream?
    @State private var episode: Episode?
    @State private var series: Series?
    @State private var allEpisodes: [Episode] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let movie {
                PlayerView(
                    title: movie.name,
                    urlString: movie.url ?? "",
                    kind: .vod,
                    contentID: String(movie.id)
                )
            } else if let episode, let series {
                PlayerView(
                    title: episode.title,
                    urlString: episode.url ?? "",
                    kind: .vod,
                    contentID: episode.id,
                    seriesContext: SeriesPlaybackContext(
                        seriesID: series.id,
                        seriesTitle: series.name,
                        plot: series.plot,
                        episodes: allEpisodes,
                        initialEpisodeID: episode.id
                    )
                )
            } else if loading {
                ZStack {
                    Theme.background.ignoresSafeArea()
                    ProgressView("Preparing playback…")
                        .tint(Theme.accentBright)
                }
            } else {
                ZStack {
                    Theme.background.ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("Unable to resume")
                            .font(.headline)
                        Text(errorMessage ?? "This item is no longer available from the saved source.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 460)
                    }
                    .padding()
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
        movie = nil
        episode = nil
        series = nil
        allEpisodes = []

        guard let source = store.sources.first(where: { $0.id == record.sourceID }) else {
            errorMessage = "The source used for this item is not available on this device."
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
            guard let movieID = Int(record.contentID),
                  let resolved = library.movies.first(where: { $0.id == movieID }) else {
                errorMessage = "The movie could not be found in the current source library."
                loading = false
                return
            }
            movie = resolved

        case .episode:
            guard let seriesID = record.seriesID,
                  let resolvedSeries = library.series.first(where: { $0.id == seriesID }) else {
                errorMessage = "The series for this episode could not be identified on this device."
                loading = false
                return
            }
            guard source.kind == .xtream,
                  let server = source.serverURL,
                  let username = source.username,
                  let password = source.password else {
                errorMessage = "This episode requires the original provider source credentials on this device."
                loading = false
                return
            }

            do {
                let client = XtreamClient(
                    serverURL: library.resolvedProviderBaseURL ?? server,
                    username: username,
                    password: password
                )
                let episodes = try await client.seriesInfo(seriesId: seriesID)
                guard let resolvedEpisode = episodes.first(where: { $0.id == record.contentID }) else {
                    errorMessage = "The episode is no longer available from this source."
                    loading = false
                    return
                }
                series = resolvedSeries
                allEpisodes = episodes
                episode = resolvedEpisode
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        loading = false
    }
}
