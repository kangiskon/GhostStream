import Foundation

@main
struct Regression {
    static func main() {
        let a = XtreamClient.candidateBaseURLs("example.com:1234/player_api.php?username=x&password=y")
        precondition(a.contains("https://example.com:1234"))
        precondition(a.contains("http://example.com:1234"))

        let b = XtreamClient.candidateBaseURLs("https://example.com:1234/panel/player_api.php?username=x")
        precondition(b.first == "https://example.com:1234/panel")
        precondition(b.contains("https://example.com:1234"))

        let c = XtreamClient.candidateBaseURLs("http://example.com:8080")
        precondition(c.first == "http://example.com:8080")
        precondition(c.contains("https://example.com:8080"))

        print("Xtream 404 candidate regression passed")
    }
}
