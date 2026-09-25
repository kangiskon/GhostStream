import Foundation

struct TVCredentialTransferDTO: Codable, Identifiable {
    let id: UUID
    let senderDeviceID: UUID
    let recipientDeviceID: UUID
    let ephemeralPublicKey: String
    let nonce: String
    let ciphertext: String
    let createdAt: Date
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id, nonce, ciphertext
        case senderDeviceID = "sender_device_id"
        case recipientDeviceID = "recipient_device_id"
        case ephemeralPublicKey = "ephemeral_public_key"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

struct TVCredentialTransferService {
    private let baseURL = URL(string: "https://ghoststreams.ink/api/v1")!

    func receivePending(pairingService: TVPairingService = .shared) async throws -> Int {
        let accessToken = try await pairingService.validAccessToken()
        let transfers: [TVCredentialTransferDTO] = try await request(
            path: "devices/me/transfers",
            method: "GET",
            accessToken: accessToken,
            body: Optional<String>.none
        )
        guard !transfers.isEmpty else { return 0 }

        let identity = try TVDeviceIdentityStore.shared.loadOrCreate()
        let privateKey = try TVDeviceIdentityStore.shared.loadPrivateKey()
        var imported = 0

        for transfer in transfers {
            let envelope = SealedCredentialEnvelope(
                senderDeviceID: transfer.senderDeviceID,
                recipientDeviceID: transfer.recipientDeviceID,
                ephemeralPublicKey: transfer.ephemeralPublicKey,
                nonce: transfer.nonce,
                ciphertext: transfer.ciphertext
            )
            let payload = try CredentialEnvelope.open(
                envelope,
                recipientPrivateKey: privateKey,
                expectedRecipientDeviceID: identity.id
            )
            let source = try payload.makeSource()

            await MainActor.run {
                if SourceStore.shared.sources.contains(where: { $0.id == source.id }) {
                    SourceStore.shared.update(source)
                } else {
                    SourceStore.shared.add(source)
                }
            }

            let _: TVEmptyResponse = try await request(
                path: "devices/me/transfers/\(transfer.id.uuidString)",
                method: "DELETE",
                accessToken: accessToken,
                body: Optional<String>.none
            )
            imported += 1
        }

        return imported
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        accessToken: String,
        body: Body?
    ) async throws -> Response {
        var url = baseURL
        for segment in path.split(separator: "/") {
            url.appendPathComponent(String(segment))
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        if let body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TVPairingError.invalidResponse
        }

        if Response.self == TVEmptyResponse.self, data.isEmpty {
            return TVEmptyResponse() as! Response
        }

        let decoder = JSONDecoder()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = fractional.date(from: value) ?? standard.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }
        return try decoder.decode(Response.self, from: data)
    }
}

private struct TVEmptyResponse: Codable {
    init() {}
}
