import SwiftUI

struct GhostMoreView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var store: SourceStore

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("MORE")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .tracking(2)

                        accountCard

                        VStack(spacing: 10) {
                            NavigationLink { LauncherView() } label: {
                                MoreRow(icon: "externaldrive.fill", title: "Sources", detail: "(store.sources.count) saved")
                            }
                            NavigationLink { SettingsView() } label: {
                                MoreRow(icon: "slider.horizontal.3", title: "Playback Settings", detail: "Player and app preferences")
                            }
                        }

                        if accountStore.isSignedIn {
                            Button(role: .destructive) {
                                Task { await accountStore.signOut() }
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Sign Out").fontWeight(.semibold)
                                    Spacer()
                                }
                                .frame(minHeight: 52)
                                .padding(.horizontal, 16)
                                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("GhostStream Account", systemImage: "person.crop.circle.fill")
                .font(.headline)
            Text(accountStore.account?.email ?? "Local Mode")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            HStack {
                statusChip(accountStore.isSignedIn ? "SYNC ON" : "LOCAL", active: accountStore.isSignedIn)
                statusChip("(accountStore.devices.filter { $0.revokedAt == nil }.count) DEVICES", active: !accountStore.devices.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }

    private func statusChip(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(active ? Theme.accentBright : Theme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.055), in: Capsule())
    }
}

private struct MoreRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accentBright)
                .frame(width: 38, height: 38)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.muted)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }
}
