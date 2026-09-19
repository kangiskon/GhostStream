import Foundation

@main
struct GenreClassifierRegression {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        let action = StandardMediaGenre.classify(categoryName: "|USA| ACTION & ADVENTURE", title: "Test", plot: nil)
        expect(action.contains(.actionAdventure), "raw provider Action category should map to Action & Adventure")

        let kids = StandardMediaGenre.classify(categoryName: "UK - KIDS / FAMILY", title: "Test", plot: nil)
        expect(kids.contains(.kidsFamily), "Kids/Family should normalize")

        let sciFi = StandardMediaGenre.classify(categoryName: "MOVIES: SCI-FI & FANTASY 4K", title: "Test", plot: nil)
        expect(sciFi.contains(.sciFiFantasy), "Sci-Fi/Fantasy should normalize despite prefixes/quality tags")

        let mixed = StandardMediaGenre.classify(categoryName: "Action Comedy", title: "Test", plot: nil)
        expect(mixed.contains(.actionAdventure) && mixed.contains(.comedy), "multi-genre provider category should appear in both matching standard genres")

        let seriesFallback = StandardMediaGenre.classify(categoryName: "US SERIES", title: "Unknown", plot: "A detective investigates a murder mystery and organized crime.")
        expect(seriesFallback.contains(.crime), "series plot fallback should classify crime")
        expect(seriesFallback.contains(.thrillerMystery), "series plot fallback should classify mystery")

        let other = StandardMediaGenre.classify(categoryName: "2026 NEW RELEASES", title: "Untitled", plot: nil)
        expect(other == [.other], "unclassifiable items should land in Other")

        print("Genre classifier regression passed")
    }
}
