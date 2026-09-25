import SwiftUI

struct TVSettingsView: View {
    @EnvironmentObject private var store: SourceStore
    @Binding var showSources: Bool
    @Binding var showPairing: Bool

    var body: some View {
        ZStack {
            TVTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SETTINGS")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .tracking(3)
                        Text("Sources, account connection, privacy, and this Apple TV")
                            .font(.headline)
                            .foregroundStyle(TVTheme.muted)
                    }

                    HStack(spacing: 22) {
                        settingCard(
                            icon: "externaldrive.fill",
                            title: "Sources",
                            detail: "\(store.sources.count) saved on this Apple TV"
                        ) {
                            showSources = true
                        }

                        settingCard(
                            icon: "qrcode",
                            title: "Pair Device",
                            detail: TVSessionVault.readRefreshToken() == nil
                                ? "Connect this Apple TV to your account"
                                : "Pair another trusted device"
                        ) {
                            showPairing = true
                        }
                    }

                    HStack(spacing: 22) {
                        infoCard(
                            icon: "lock.shield.fill",
                            title: "Credential Privacy",
                            detail: "Provider credentials remain in protected local storage and are transferred only as end-to-end encrypted packages."
                        )
                        infoCard(
                            icon: "waveform.path.ecg",
                            title: "Diagnostic Privacy",
                            detail: "Only sanitized health results sync. Raw source URLs, passwords, playlists, and authorization headers stay local."
                        )
                    }

                    infoCard(
                        icon: "person.crop.circle.badge.checkmark",
                        title: "GhostStream Account",
                        detail: TVSessionVault.readRefreshToken() == nil
                            ? "This Apple TV is not currently connected to a GhostStream account."
                            : "This Apple TV is paired and can synchronize Continue Watching and Source Health."
                    )
                }
                .padding(.horizontal, 72)
                .padding(.vertical, 46)
            }
        }
    }

    private func settingCard(
        icon: String,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(TVTheme.accentBright)
                    .frame(width: 78, height: 78)
                    .background(TVTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 7) {
                    Text(title).font(.title3.bold()).foregroundStyle(.white)
                    Text(detail).font(.headline).foregroundStyle(TVTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title3.bold())
                    .foregroundStyle(TVTheme.muted)
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 132)
            .background(TVTheme.cardGradient, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(TVTheme.border, lineWidth: 1))
        }
        .buttonStyle(TVGhostFocusStyle())
        .tvGhostFocus(cornerRadius: 24)
    }

    private func infoCard(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(TVTheme.accentBright)
                .frame(width: 78, height: 78)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.title3.bold())
                Text(detail).font(.headline).foregroundStyle(TVTheme.muted)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 128)
        .background(TVTheme.card, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(TVTheme.border, lineWidth: 1))
    }
}
