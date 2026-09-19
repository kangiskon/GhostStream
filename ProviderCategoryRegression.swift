import Foundation

@main
struct ProviderCategoryRegression {
    static func main() {
        let categories = [
            Category(id: "10", name: "USA | ACTION"),
            Category(id: "20", name: "NEW RELEASES"),
            Category(id: "30", name: "EMPTY")
        ]

        let movies = [
            VODStream(id: 1, name: "Movie A", icon: nil, categoryId: "20", containerExtension: "mp4", directSource: nil, url: nil),
            VODStream(id: 2, name: "Movie B", icon: nil, categoryId: "10", containerExtension: "mp4", directSource: nil, url: nil)
        ]
        let shows = [
            Series(id: 1, name: "Show A", cover: nil, categoryId: "10", plot: nil)
        ]
        let channels = [
            Channel(id: "c1", name: "Channel A", url: "http://example/a", group: "20"),
            Channel(id: "c2", name: "Channel B", url: "http://example/b", group: "10")
        ]

        let movieBuckets = ProviderCategoryIndex.movieBuckets(items: movies)
        let seriesBuckets = ProviderCategoryIndex.seriesBuckets(items: shows)
        let liveBuckets = ProviderCategoryIndex.liveBuckets(items: channels)

        precondition(movieBuckets["20"]?.map(\.id) == [1])
        precondition(movieBuckets["10"]?.map(\.id) == [2])
        precondition(seriesBuckets["10"]?.map(\.id) == [1])
        precondition(liveBuckets["20"]?.map(\.id) == ["c1"])
        precondition(liveBuckets["10"]?.map(\.id) == ["c2"])

        let visible = ProviderCategoryIndex.nonEmptyCategories(
            categories,
            counts: movieBuckets.mapValues(\.count)
        )
        precondition(visible.map(\.id) == ["10", "20"])
        precondition(visible.map(\.name) == ["USA | ACTION", "NEW RELEASES"])

        print("provider category regression passed")
    }
}
