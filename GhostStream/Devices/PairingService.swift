import Foundation

struct PairingService {
    private let api: GhostStreamAPIClient

    init(api: GhostStreamAPIClient = GhostStreamAPIClient()) {
        self.api = api
    }

    func claim(qrPayload: String, accessToken: String) async throws -> PairingClaimDTO {
        guard let url = URL(string: qrPayload),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let pairingID = components.queryItems?.first(where: { $0.name == "pairing_id" })?.value,
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              UUID(uuidString: pairingID) != nil,
              token.count >= 32 else {
            throw APIError.invalidResponse
        }

        return try await api.send(
            path: "pairing/claim",
            body: PairingClaimBody(pairingID: pairingID, qrToken: token, manualCode: nil),
            accessToken: accessToken
        )
    }

    func claim(code: String, accessToken: String) async throws -> PairingClaimDTO {
        guard code.count == 6, code.allSatisfy({ $0.isNumber }) else {
            throw PairingServiceError.invalidManualCode
        }

        return try await api.send(
            path: "pairing/claim",
            body: PairingClaimBody(pairingID: nil, qrToken: nil, manualCode: code),
            accessToken: accessToken
        )
    }

    func approve(pairingID: UUID, accessToken: String, approve: Bool = true) async throws -> PairingStateDTO {
        try await api.send(
            path: "pairing/(pairingID.uuidString)/approve",
            body: PairingApproveBody(approve: approve),
            accessToken: accessToken
        )
    }
}

enum PairingServiceError: LocalizedError {
    case invalidManualCode

    var errorDescription: String? {
        switch self {
        case .invalidManualCode:
            return "Enter the 6-digit code shown on the other GhostStream device."
        }
    }
}

private struct PairingClaimBody: Codable {
    let pairingID: String?
    let qrToken: String?
    let manualCode: String?

    enum CodingKeys: String, CodingKey {
        case pairingID = "pairing_id"
        case qrToken = "qr_token"
        case manualCode = "manual_code"
    }
}

private struct PairingApproveBody: Codable {
    let approve: Bool
}
