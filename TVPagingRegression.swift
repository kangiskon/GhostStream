import Foundation

@main
struct TVPagingRegression {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        expect(TVMediaPaging.initialLimit >= 60 && TVMediaPaging.initialLimit <= 100,
               "initial page should be between 60 and 100 items")
        expect(TVMediaPaging.nextLimit(current: 60, total: 21000) > 60,
               "next page should increase the visible item limit")
        expect(TVMediaPaging.nextLimit(current: 60, total: 80) == 80,
               "next page should clamp to the total")
        expect(TVMediaPaging.nextLimit(current: 100, total: 100) == 100,
               "next page should not exceed the total")
        print("PASS: TV media paging policy")
    }
}
