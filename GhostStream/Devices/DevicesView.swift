import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var accountStore: AccountStore

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("DEVICES")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .tracking(2)
                            Text("Pair, trust, and manage the devices connected to your GhostStream account.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        }

                        NavigationLink {
                            PairDeviceView()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title2)
                                    .foregroundStyle(Theme.accentBright)
                                    .frame(width: 52, height: 52)
                                    .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Pair New Device")
                                        .font(.headline)
                                    Text("Scan QR code or enter a 6-digit code")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Theme.muted)
                            }
                            .padding(17)
                            .background(Theme.cardGradient, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Label("TRUSTED DEVICES", systemImage: "checkmark.shield.fill")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.accentBright)

                        if accountStore.devices.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "appletv")
                                    .font(.system(size: 34))
                                    .foregroundStyle(Theme.accentBright)
                                Text("No trusted devices yet")
                                    .font(.headline)
                                Text("Open GhostStream on Apple TV and choose Pair Device to display its QR code and 6-digit code.")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .padding(.horizontal, 18)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
                        } else {
                            ForEach(accountStore.devices) { device in
                                NavigationLink {
                                    DeviceDetailView(device: device)
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: icon(for: device.platform))
                                            .font(.title2)
                                            .foregroundStyle(Theme.accentBright)
                                            .frame(width: 50, height: 50)
                                            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(device.displayName)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text("\(device.platform.uppercased()) • \(device.osVersion)")
                                                .font(.caption)
                                                .foregroundStyle(Theme.muted)
                                            Text(device.revokedAt == nil ? "Trusted" : "Revoked")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(device.revokedAt == nil ? Color.green : Color.red)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(Theme.muted)
                                    }
                                    .padding(16)
                                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await accountStore.reloadDevices()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func icon(for platform: String) -> String {
        switch platform {
        case "tvos": return "appletv.fill"
        case "ipados": return "ipad"
        default: return "iphone"
        }
    }
}
