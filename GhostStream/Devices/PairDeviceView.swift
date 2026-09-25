import SwiftUI

struct PairDeviceView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingScanner = false
    @State private var showingManualEntry = false
    @State private var manualCode = ""
    @State private var claimedDevice: PairingClaimDTO?
    @State private var showApproval = false
    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var isError = false

    private let service = PairingService()

    private var validManualCode: Bool {
        manualCode.count == 6 && manualCode.allSatisfy { $0.isNumber }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.background2, Theme.background, .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "rectangle.connected.to.line.below")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(Theme.accentBright)
                        .frame(width: 96, height: 96)
                        .background(Theme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 28))
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.border, lineWidth: 1))

                    VStack(spacing: 8) {
                        Text("PAIR A DEVICE")
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .tracking(2)
                        Text("Scan the QR code shown by GhostStream on Apple TV or another device. You can also enter its 6-digit code.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(isWorking)

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showingManualEntry.toggle()
                        }
                    } label: {
                        Label("Enter Code Instead", systemImage: "number.square")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accentBright)

                    if showingManualEntry {
                        VStack(spacing: 12) {
                            TextField("000000", text: $manualCode)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .tracking(9)
                                .padding()
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                                .onChange(of: manualCode) { newValue in
                                    manualCode = String(newValue.filter { $0.isNumber }.prefix(6))
                                }

                            Button("Find Device") {
                                Task { await claimManualCode() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .disabled(!validManualCode || isWorking)
                        }
                    }

                    if isWorking {
                        ProgressView("Checking pairing session…")
                            .tint(Theme.accentBright)
                    }

                    if let claimedDevice {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(claimedDevice.displayName, systemImage: claimedDevice.platform == "tvos" ? "appletv.fill" : "iphone")
                                .font(.headline)
                            Text("(claimedDevice.platform.uppercased()) • (claimedDevice.osVersion)")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                            Text("Code expires (claimedDevice.expiresAt.formatted(date: .omitted, time: .shortened)).")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
                    }

                    if let statusMessage {
                        Label(statusMessage, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(isError ? Color.orange : Color.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: 520)
                .padding(22)
            }
        }
        .navigationTitle("Pair Device")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingScanner) {
            NavigationStack {
                QRCodeScannerView { value in
                    showingScanner = false
                    Task { await claimQR(value) }
                } onError: { message in
                    showingScanner = false
                    statusMessage = message
                    isError = true
                }
                .ignoresSafeArea()
                .navigationTitle("Scan GhostStream QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showingScanner = false }
                    }
                }
            }
        }
        .confirmationDialog(
            "Approve Device",
            isPresented: $showApproval,
            titleVisibility: .visible
        ) {
            Button("Approve Device") {
                Task { await approveClaimedDevice() }
            }
            Button("Cancel", role: .cancel) {
                claimedDevice = nil
            }
        } message: {
            Text("Trust (claimedDevice?.displayName ?? "this device") and allow it to join your GhostStream account?")
        }
    }

    @MainActor
    private func claimQR(_ payload: String) async {
        isWorking = true
        statusMessage = nil
        isError = false
        defer { isWorking = false }

        do {
            let token = try await accountStore.validAccessToken()
            claimedDevice = try await service.claim(qrPayload: payload, accessToken: token)
            showApproval = true
        } catch {
            statusMessage = pairingMessage(for: error)
            isError = true
        }
    }

    @MainActor
    private func claimManualCode() async {
        isWorking = true
        statusMessage = nil
        isError = false
        defer { isWorking = false }

        do {
            let token = try await accountStore.validAccessToken()
            claimedDevice = try await service.claim(code: manualCode, accessToken: token)
            showApproval = true
        } catch {
            statusMessage = pairingMessage(for: error)
            isError = true
        }
    }

    @MainActor
    private func approveClaimedDevice() async {
        guard let claimedDevice else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            let token = try await accountStore.validAccessToken()
            let state = try await service.approve(pairingID: claimedDevice.pairingID, accessToken: token)
            guard state.state == "approved" else {
                throw APIError.invalidResponse
            }
            await accountStore.reloadDevices()
            statusMessage = "(claimedDevice.displayName) is now a trusted GhostStream device."
            isError = false
            self.claimedDevice = nil
            manualCode = ""
        } catch {
            statusMessage = pairingMessage(for: error)
            isError = true
        }
    }

    private func pairingMessage(for error: Error) -> String {
        if case APIError.server(let statusCode, let code, _) = error {
            if statusCode == 410 || code == "pairing_expired" {
                return "That pairing code expired. Generate a new code on the other device and try again."
            }
            if code == "pairing_already_claimed" {
                return "That pairing session has already been used. Generate a new code."
            }
        }
        return error.localizedDescription
    }
}
