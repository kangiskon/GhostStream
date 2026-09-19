import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

func expect(_ actual: [String], _ expected: [String], _ name: String) {
    guard actual == expected else {
        fputs("FAIL \(name): \(actual) != \(expected)\n", stderr)
        exit(1)
    }
}

@main
struct Regression {
    static func main() {
        expect(XtreamClient.connectionCandidates(for: "example.com:433"),
               ["https://example.com:433", "http://example.com:433"],
               "no-scheme secure-first fallback")
        expect(XtreamClient.connectionCandidates(for: "https://example.com:433"),
               ["https://example.com:433"],
               "explicit https respected")
        expect(XtreamClient.connectionCandidates(for: "http://example.com:8080/player_api.php?x=1"),
               ["http://example.com:8080"],
               "explicit http respected and endpoint stripped")
        print("PASS Xtream connection candidate regression")
    }
}
