import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SourceStore
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var epg: EPGService

    @State private var showAddSource = false
    @State private var showLauncher = false
    @State private var showPlayerSettings = false
    @State private var showPlaybackOptions = false
    @State private var showPrivacy = false
    @State private var showAppStyle = false

    var body: some View {
        NavigationStack {
            ZStack {
                GhostScreenBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Settings")
                                .font(.title3.weight(.black))
                                .foregroundStyle(.white)
                            Spacer()
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(Theme.card, in: Circle())
                                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Close Settings")
                        }
                        settingRow(icon: "plus.rectangle.on.rectangle", title: "Add Source", subtitle: "M3U, provider login, single stream") { showAddSource = true }
                        settingRow(icon: "externaldrive.fill", title: "Saved Sources", subtitle: "Manage and switch services") { showLauncher = true }
                        settingRow(icon: "play.rectangle.fill", title: "Player Settings", subtitle: "Player behavior and controls") { showPlayerSettings = true }
                        settingRow(icon: "slider.horizontal.3", title: "Playback Options", subtitle: "Streaming and playback information") { showPlaybackOptions = true }
                        settingRow(icon: "lock.shield.fill", title: "Privacy", subtitle: "Saved locally on this device") { showPrivacy = true }
                        settingRow(icon: "sparkles", title: "App Style", subtitle: "Ghost theme") { showAppStyle = true }

                        if store.activeSource != nil {
                            settingRow(icon: "rectangle.portrait.and.arrow.right", title: "Change Source", subtitle: "Switch or manage saved services") {
                                openSourceSwitcher()
                            }
                        }

                        disclosureCard
                        aboutCard
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddSource) {
                NavigationStack { AddSourceView() }
                    .environmentObject(store)
                    .environmentObject(library)
                    .environmentObject(epg)
            }
            .sheet(isPresented: $showPlayerSettings) {
                SettingsInfoSheet(
                    title: "Player Settings",
                    icon: "play.rectangle.fill",
                    rows: [
                        ("Playback Engine", "GhostStream automatically prefers the native Apple player and falls back to the compatibility engine when needed."),
                        ("Controls", "Tap the video to reveal Back, Play/Pause/Resume, and the seek bar when the stream is seekable."),
                        ("Rotation", "Playback rotates to landscape automatically and returns to portrait when you leave the player.")
                    ]
                )
            }
            .sheet(isPresented: $showPlaybackOptions) {
                SettingsInfoSheet(
                    title: "Playback Options",
                    icon: "slider.horizontal.3",
                    rows: [
                        ("Movies & Series", "On-demand titles include a scrub bar so you can jump forward or backward."),
                        ("Live TV", "Live streams show a scrub bar only when the provider exposes a DVR/seekable window."),
                        ("Quality", "GhostStream follows the stream quality supplied by your provider and uses hardware playback when available.")
                    ]
                )
            }
            .sheet(isPresented: $showPrivacy) {
                SettingsInfoSheet(
                    title: "Privacy",
                    icon: "lock.shield.fill",
                    rows: [
                        ("Source Details", "Saved source names, provider usernames, server addresses, and preferences remain on this device."),
                        ("Provider Passwords", "Compatible provider login passwords are stored in Apple Keychain. Playlist URLs may themselves contain access tokens."),
                        ("Provider Connections", "Connecting or streaming sends requests to the server you choose. Your provider can see your network address and may receive your login or stream token. HTTP connections are not encrypted; use HTTPS when available."),
                        ("Playback Data", "Favorites and resume positions are stored locally. The app may cache provider titles and artwork to load faster."),
                        ("Content", "GhostStream does not provide or bundle channels, movies, series, or subscriptions."),
                        ("Control", "Remove saved sources in Saved Sources to delete their saved Keychain passwords and library metadata cache. Other local preferences and playback history may remain until app data is cleared. Removing a source does not close a provider account.")
                    ]
                )
            }
            .sheet(isPresented: $showAppStyle) {
                SettingsInfoSheet(
                    title: "App Style",
                    icon: "sparkles",
                    rows: [
                        ("Theme", "GhostStream uses the black and purple media-center theme across iPhone, iPad, and Apple TV."),
                        ("Focus", "Apple TV uses compact poster focus rings; iPhone and iPad use touch-first controls."),
                        ("Branding", "The GhostStream icon and interface use the current purple GhostStream branding.")
                    ]
                )
            }
            .fullScreenCover(isPresented: $showLauncher) {
                LauncherView(onClose: { showLauncher = false })
                    .environmentObject(store)
                    .environmentObject(library)
                    .environmentObject(epg)
            }
        }
    }

    private func settingRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.10))
                    Image(systemName: icon).font(.system(size: 19, weight: .semibold)).foregroundStyle(Theme.accent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Text(subtitle).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.accent.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 64)
            .background(Theme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var disclosureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("CONTENT & RIGHTS", systemImage: "checkmark.shield.fill")
                .font(.caption.bold()).tracking(1.1).foregroundStyle(Theme.accent)
            Text("GhostStream is a general media player. It does not provide, sell, host, or bundle channels, movies, series, subscriptions, playlists, credentials, or streaming services.")
                .font(.footnote).foregroundStyle(Theme.muted)
            Text("Only add sources and play content you are authorized to access.")
                .font(.footnote.weight(.semibold)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.cardGradient, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
        .padding(.top, 4)
    }

    private var aboutCard: some View {
        HStack {
            Image("GhostBrandExact").resizable().scaledToFill().frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text("GHOSTSTREAM").font(.headline).tracking(1.1)
                Text("Version 1.0").font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
    }

    private func openSourceSwitcher() {
        showLauncher = true
    }
}


private struct SettingsInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let icon: String
    let rows: [(String, String)]

    var body: some View {
        NavigationStack {
            ZStack {
                GhostScreenBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 12)

                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(row.0)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(row.1)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
