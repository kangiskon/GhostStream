import SwiftUI

struct TVDevicesView: View {
    @Binding var showPairing: Bool

    @State private var devices: [TVAccountDeviceDTO] = []
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            TVTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DEVICES")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .tracking(3)
                            Text("Trusted iPhone, iPad, and Apple TV devices on your GhostStream account")
                                .font(.headline)
                                .foregroundStyle(TVTheme.muted)
                        }

                        Spacer()

                        Button {
                            showPairing = true
                        } label: {
                            Label("Pair New Device", systemImage: "qrcode")
                                .font(.headline.weight(.bold))
                                .padding(.horizontal, 28)
                                .frame(height: 58)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TVTheme.accent)

                        Button {
                            Task { await reload() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.headline)
                                .padding(.horizontal, 22)
                                .frame(height: 58)
                        }
                        .buttonStyle(.bordered)
                    }

                    if TVSessionVault.readRefreshToken() == nil {
                        messageCard(
                            icon: "qrcode",
                            title: "Pair this Apple TV",
                            detail: "Pair with a trusted iPhone or iPad to connect this Apple TV to your GhostStream account."
                        )
                    } else if loading && devices.isEmpty {
                        ProgressView("Loading trusted devices…")
                            .tint(TVTheme.accentBright)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if let errorMessage {
                        messageCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Could not load devices",
                            detail: errorMessage
                        )
                    } else if devices.isEmpty {
                        messageCard(
                            icon: "rectangle.connected.to.line.below",
                            title: "No trusted devices returned",
                            detail: "Use Pair New Device to connect another GhostStream device."
                        )
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 360), spacing: 22)],
                            spacing: 22
                        ) {
                            ForEach(devices) { device in
                                deviceCard(device)
                            }
                        }
                    }
                }
                .padding(.horizontal, 72)
                .padding(.vertical, 46)
            }
        }
        .task {
            await reload()
        }
    }

    private func deviceCard(_ device: TVAccountDeviceDTO) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon(for: device.platform))
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(TVTheme.accentBright)
                .frame(width: 76, height: 76)
                .background(TVTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 7) {
                Text(device.displayName)
                    .font(.title3.weight(.bold))
                Text("\(device.platform.uppercased()) • \(device.osVersion)")
                    .font(.headline)
                    .foregroundStyle(TVTheme.muted)
                HStack(spacing: 8) {
                    Circle()
                        .fill(device.revokedAt == nil ? Color.green : Color.red)
                        .frame(width: 9, height: 9)
                    Text(device.revokedAt == nil ? device.trustState.capitalized : "Revoked")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(device.revokedAt == nil ? Color.green : Color.red)
                }
                Text("Last seen \(device.lastSeenAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(TVTheme.muted)
            }

            Spacer()
        }
        .padding(22)
        .frame(minHeight: 128)
        .background(TVTheme.cardGradient, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(TVTheme.border, lineWidth: 1))
    }

    private func messageCard(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(TVTheme.accentBright)
                .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.title3.bold())
                Text(detail).font(.headline).foregroundStyle(TVTheme.muted)
            }
            Spacer()
        }
        .padding(26)
        .background(TVTheme.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(TVTheme.border, lineWidth: 1))
    }

    private func icon(for platform: String) -> String {
        switch platform {
        case "tvos": return "appletv.fill"
        case "ipados": return "ipad"
        default: return "iphone"
        }
    }

    @MainActor
    private func reload() async {
        guard TVSessionVault.readRefreshToken() != nil else {
            devices = []
            return
        }
        loading = true
        errorMessage = nil
        defer { loading = false }
        do {
            devices = try await TVSyncService.shared.fetchDevices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
