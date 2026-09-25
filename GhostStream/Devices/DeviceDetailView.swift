import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var store: SourceStore
    @Environment(\.dismiss) private var dismiss

    let device: DeviceDTO

    @State private var displayName: String
    @State private var showRevokeConfirmation = false
    @State private var showSourcePicker = false
    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    private let transferService = CredentialTransferService()

    init(device: DeviceDTO) {
        self.device = device
        _displayName = State(initialValue: device.displayName)
    }

    private var isCurrentDevice: Bool {
        (try? DeviceIdentityService.shared.loadOrCreate().id) == device.id
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        Image(systemName: platformIcon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.accentBright)
                            .frame(width: 66, height: 66)
                            .background(Theme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 19))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.displayName)
                                .font(.title2.weight(.bold))
                            Label(
                                device.revokedAt == nil ? "Trusted" : "Revoked",
                                systemImage: device.revokedAt == nil ? "checkmark.shield.fill" : "xmark.shield.fill"
                            )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(device.revokedAt == nil ? Color.green : Color.red)
                        }
                    }

                    detailCard("DEVICE STATUS") {
                        detailRow("Platform", value: device.platform.uppercased())
                        detailRow("OS", value: device.osVersion)
                        detailRow("Last Seen", value: device.lastSeenAt.formatted(date: .abbreviated, time: .shortened))
                        detailRow("Sync Status", value: syncStatus)
                        detailRow("Source Credentials", value: sourceCredentialStatus)
                    }

                    detailCard("RENAME DEVICE") {
                        TextField("Device name", text: $displayName)
                            .textInputAutocapitalization(.words)
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.border, lineWidth: 1))

                        Button("Rename Device") {
                            Task { await rename() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .disabled(isWorking || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    detailCard("SECURE SOURCE TRANSFER") {
                        Text("Send an authorized source directly to this trusted device. GhostStream relays only end-to-end encrypted ciphertext; provider credentials are decrypted only on the destination device.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)

                        Button {
                            showSourcePicker = true
                        } label: {
                            Label("Send Source", systemImage: "lock.shield.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .disabled(isWorking || isCurrentDevice || store.sources.isEmpty || device.revokedAt != nil)
                    }

                    if !isCurrentDevice {
                        detailCard("DEVICE ACCESS") {
                            Button(role: .destructive) {
                                showRevokeConfirmation = true
                            } label: {
                                Label("Revoke Device", systemImage: "xmark.shield.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isWorking || device.revokedAt != nil)
                        }
                    }

                    if isWorking {
                        ProgressView()
                            .tint(Theme.accentBright)
                    }
                    if let statusMessage {
                        Label(statusMessage, systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(18)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Device")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Send Source", isPresented: $showSourcePicker, titleVisibility: .visible) {
            ForEach(store.sources) { source in
                Button(source.name) {
                    Task { await send(source) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose the source to transfer securely to \(device.displayName).")
        }
        .alert("Revoke Device?", isPresented: $showRevokeConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Revoke Device", role: .destructive) {
                Task { await revoke() }
            }
        } message: {
            Text("This immediately revokes \(device.displayName), its sessions, and any queued encrypted source transfers.")
        }
    }

    private var platformIcon: String {
        switch device.platform {
        case "tvos": return "appletv.fill"
        case "ipados": return "ipad"
        default: return "iphone"
        }
    }

    private var syncStatus: String {
        switch accountStore.syncState {
        case .idle: return "Up to date"
        case .syncing: return "Syncing"
        case .offline: return "Offline"
        case .failed: return "Needs attention"
        }
    }

    private var sourceCredentialStatus: String {
        if isCurrentDevice {
            return store.sources.isEmpty ? "None stored locally" : "\(store.sources.count) local source(s)"
        }
        return "Transferred only with Send Source"
    }

    private func detailCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(Theme.accentBright)
            content()
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    @MainActor
    private func rename() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await accountStore.renameDevice(device, displayName: displayName)
            statusMessage = "Device renamed."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func send(_ source: Source) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await transferService.send(source: source, to: device, accountStore: accountStore)
            statusMessage = "\(source.name) was encrypted for \(device.displayName) and queued for delivery."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func revoke() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await accountStore.revokeDevice(device)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
