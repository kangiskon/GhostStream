import SwiftUI

@main
struct GhostStreamTVApp: App {
    @StateObject private var store = SourceStore.shared
    @StateObject private var library = LibraryViewModel()
    @StateObject private var epg = EPGService()

    var body: some Scene {
        WindowGroup {
            TVRootView()
                .environmentObject(store)
                .environmentObject(library)
                .environmentObject(epg)
                .preferredColorScheme(.dark)
        }
    }
}
