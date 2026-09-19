import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@main
struct Regression {
    static func main() {
        let cases: [(String, String)] = [
            ("example.com:433", "https://example.com:433"),
            ("https://example.com:433/player_api.php?username=x&password=y", "https://example.com:433"),
            ("http://example.com:8080/get.php?username=x", "http://example.com:8080")
        ]
        var failed = false
        for (input, expected) in cases {
            let actual = XtreamClient.normalize(input)
            if actual != expected {
                failed = true
                print("FAIL normalize(\(input)) => \(actual), expected \(expected)")
            }
        }
        if failed { exit(1) }
        print("PASS Xtream normalize regression")
    }
}
