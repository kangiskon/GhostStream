import Foundation

@main
struct CacheModelRegression {
    static func main() throws {
        var channel = Channel(id: "1", name: "Live", url: "https://example.com/secret-password/live", logo: "https://example.com/secret-password/poster", group: "News", tvgId: "news", streamId: 1)
        var movie = VODStream(id: 7, name: "Movie", icon: "https://example.com/secret-password/image", categoryId: "movies", containerExtension: "mp4", directSource: "https://example.com/secret-password/direct", url: "https://example.com/secret-password/movie")
        var show = Series(id: 9, name: "Show", cover: "https://example.com/secret-password/cover", categoryId: "series", plot: "Synopsis")
        channel.url = ""; channel.logo = nil
        movie.icon = nil; movie.directSource = nil; movie.url = nil
        show.cover = nil
        let data = try JSONEncoder().encode([channel])
        let text = String(decoding: data, as: UTF8.self)
        precondition(!text.contains("secret-password"))
        let decodedChannel = try JSONDecoder().decode([Channel].self, from: data)
        precondition(decodedChannel.first?.streamId == 1)
        let other = try JSONEncoder().encode([movie])
        precondition(!String(decoding: other, as: UTF8.self).contains("secret-password"))
        let decodedVODStream = try JSONDecoder().decode([VODStream].self, from: other)
        precondition(decodedVODStream.count == 1)
        let series = try JSONEncoder().encode([show])
        precondition(!String(decoding: series, as: UTF8.self).contains("secret-password"))
        let decodedSeries = try JSONDecoder().decode([Series].self, from: series)
        precondition(decodedSeries.count == 1)
        let categories = try JSONEncoder().encode([Category(id: "1", name: "News")])
        let decodedCategory = try JSONDecoder().decode([Category].self, from: categories)
        precondition(decodedCategory.count == 1)
        print("PASS cache model Codable and no credential-bearing URL fields")
    }
}
