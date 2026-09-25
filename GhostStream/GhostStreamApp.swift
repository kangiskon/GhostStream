import SwiftUI
import UIKit

@main
struct GhostStreamApp: App {
    init() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 15/255, alpha: 0.99)
        tab.shadowColor = UIColor(red: 124/255, green: 92/255, blue: 1.0, alpha: 0.28)
        let muted = UIColor(white: 0.52, alpha: 1)
        let purple = UIColor(red: 124/255, green: 92/255, blue: 1.0, alpha: 1)
        [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance].forEach { item in
            item.normal.iconColor = muted
            item.normal.titleTextAttributes = [.foregroundColor: muted]
            item.selected.iconColor = purple
            item.selected.titleTextAttributes = [.foregroundColor: purple]
        }
        UITabBar.appearance().standardAppearance = tab
        if #available(iOS 15.0, *) { UITabBar.appearance().scrollEdgeAppearance = tab }

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 15/255, alpha: 0.96)
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = purple
    }

    @StateObject private var store = SourceStore.shared
    @StateObject private var library = LibraryViewModel()
    @StateObject private var epg = EPGService()
    @StateObject private var account = AccountStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(library)
                .environmentObject(epg)
                .environmentObject(account)
                .task {
                    GlobalDeletionCoordinator.shared.configure(
                        accountStore: account,
                        library: library,
                        epg: epg
                    )
                    _ = SourceMigrationCoordinator.shared.migrateIfNeeded()
                    await account.restoreSession()
                    SyncEngine.shared.start(accountStore: account)
                }
                .task(id: account.isSignedIn) {
                    guard account.isSignedIn else { return }
                    let inbox = CredentialTransferService()
                    while !Task.isCancelled && account.isSignedIn {
                        _ = try? await inbox.receivePending(accountStore: account)
                        try? await Task.sleep(nanoseconds: 15_000_000_000)
                    }
                }
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

enum Theme {
    static let accent = Color(red: 124/255, green: 92/255, blue: 1.0)
    static let accentBright = Color(red: 160/255, green: 128/255, blue: 1.0)
    static let background = Color(red: 11/255, green: 11/255, blue: 15/255)
    static let background2 = Color(red: 18/255, green: 12/255, blue: 28/255)
    static let card = Color(red: 17/255, green: 17/255, blue: 22/255)
    static let card2 = Color(red: 28/255, green: 24/255, blue: 44/255)
    static let muted = Color.white.opacity(0.58)
    static let border = accent.opacity(0.34)
    static let cardGradient = LinearGradient(
        colors: [Color(red: 27/255, green: 22/255, blue: 42/255), Color(red: 15/255, green: 15/255, blue: 20/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let heroGlow = LinearGradient(
        colors: [accent.opacity(0.22), accentBright.opacity(0.08), .clear],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}
