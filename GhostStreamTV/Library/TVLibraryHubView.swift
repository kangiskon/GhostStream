import SwiftUI

struct TVLibraryHubView: View {
    private enum LibrarySection: String, CaseIterable, Identifiable {
        case live = "Live TV"
        case movies = "Movies"
        case series = "Series"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .live: return "tv.fill"
            case .movies: return "film.fill"
            case .series: return "rectangle.stack.fill"
            }
        }
    }

    @State private var selection: LibrarySection = .live

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIBRARY")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .tracking(3)
                    Text("Live TV, Movies, and Series from your connected source")
                        .font(.headline)
                        .foregroundStyle(TVTheme.muted)
                }

                Spacer()

                ForEach(LibrarySection.allCases) { item in
                    Button {
                        selection = item
                    } label: {
                        Label(item.rawValue, systemImage: item.icon)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .frame(height: 52)
                            .background(
                                selection == item ? TVTheme.accent.opacity(0.30) : TVTheme.card,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(
                                    selection == item ? TVTheme.accentBright : TVTheme.border,
                                    lineWidth: selection == item ? 2 : 1
                                )
                            )
                    }
                    .buttonStyle(TVGhostFocusStyle())
                    .tvGhostFocus(cornerRadius: 26)
                }
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 22)

            Group {
                switch selection {
                case .live: TVLiveListBrowser()
                case .movies: TVMovieGrid()
                case .series: TVSeriesGrid()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(TVTheme.background)
    }
}
