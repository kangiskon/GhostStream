import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct TVPairDeviceView: View {
    var onPaired: (() -> Void)?
    var onCancel: (() -> Void)?

    @State private var session: TVPairingSessionDTO?
    @State private var stateText = "Creating a secure pairing code…"
    @State private var errorText: String?
    @State private var isWorking = false
    @AppStorage("ghoststream.tv.paired") private var isPaired = false

    private let service = TVPairingService()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 10/255, green: 7/255, blue: 19/255),
                    Color(red: 27/255, green: 15/255, blue: 48/255),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 70) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("GHOSTSTREAM")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(.white)

                    Text("Pair this Apple TV")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Open GhostStream on your trusted iPhone or iPad, go to Devices, and scan this QR code.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: 620, alignment: .leading)

                    if let session {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("OR ENTER THIS 6-DIGIT CODE")
                                .font(.caption.weight(.bold))
                                .tracking(2)
                                .foregroundStyle(Color(red: 160/255, green: 128/255, blue: 1.0))

                            Text(session.manualCode)
                                .font(.system(size: 56, weight: .black, design: .monospaced))
                                .tracking(12)
                                .foregroundStyle(.white)

                            TimelineView(.periodic(from: .now, by: 1)) { _ in
                                Text(expirationText(for: session.expiresAt))
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                        }
                    }

                    Text(stateText)
                        .font(.headline)
                        .foregroundStyle(Color(red: 160/255, green: 128/255, blue: 1.0))

                    if let errorText {
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: 620, alignment: .leading)
                    }

                    HStack(spacing: 20) {
                        if errorText != nil {
                            Button("Try Again") {
                                Task { await beginPairing() }
                            }
                        }

                        Button("Cancel") {
                            onCancel?()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    RoundedRectangle(cornerRadius: 34)
                        .fill(.white)
                        .frame(width: 430, height: 430)

                    if let session, let image = qrImage(from: session.qrPayload) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 360, height: 360)
                    } else if isWorking {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.black)
                    }
                }
                .shadow(color: Color.purple.opacity(0.35), radius: 40)
            }
            .padding(.horizontal, 100)
            .padding(.vertical, 70)
        }
        .task {
            if session == nil {
                await beginPairing()
            }
        }
        .task(id: session?.pairingID) {
            guard let session else { return }
            await poll(session)
        }
    }

    @MainActor
    private func beginPairing() async {
        isWorking = true
        errorText = nil
        stateText = "Creating a secure pairing code…"
        session = nil
        defer { isWorking = false }

        do {
            let newSession = try await service.createSession()
            session = newSession
            stateText = "Waiting for approval on your trusted device…"
        } catch {
            errorText = error.localizedDescription
            stateText = "Pairing is unavailable."
        }
    }

    private func poll(_ pairing: TVPairingSessionDTO) async {
        var delay: UInt64 = 1_000_000_000

        while !Task.isCancelled {
            if pairing.expiresAt <= Date() {
                await MainActor.run {
                    errorText = "This code expired. Select Try Again for a new pairing code."
                    stateText = "Pairing expired."
                }
                return
            }

            do {
                let state = try await service.state(for: pairing)
                if state.state == "approved" {
                    _ = try await service.complete(pairing)
                    await MainActor.run {
                        isPaired = true
                        errorText = nil
                        stateText = "Paired. This Apple TV is now trusted."
                        onPaired?()
                    }
                    return
                }
                if state.state == "rejected" || state.state == "expired" {
                    await MainActor.run {
                        errorText = state.state == "expired"
                            ? "This code expired. Select Try Again."
                            : "Pairing was cancelled on the trusted device."
                        stateText = "Not paired."
                    }
                    return
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                }
            }

            try? await Task.sleep(nanoseconds: delay)
            delay = min(UInt64(Double(delay) * 1.5), 5_000_000_000)
        }
    }

    private func expirationText(for expiresAt: Date) -> String {
        let seconds = max(0, Int(expiresAt.timeIntervalSinceNow))
        return String(format: "Code expires in %d:%02d", seconds / 60, seconds % 60)
    }

    private func qrImage(from value: String) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(value.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
