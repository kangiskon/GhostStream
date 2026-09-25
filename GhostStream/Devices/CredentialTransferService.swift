import Foundation

struct CredentialTransferService {
    private let api: GhostStreamAPIClient

    init(api: GhostStreamAPIClient = GhostStreamAPIClient()) {
        self.api = api
    }

    func send(
        source: Source,
        to recipient: DeviceDTO,
        accountStore: AccountStore
    ) async throws {
        guard let recipientPublicKey = Data(base64Encoded: recipient.publicKey) else {
            throw CredentialEnvelopeError.invalidPublicKey
        }

        let identity = try DeviceIdentityService.shared.loadOrCreate()
        let payload = CredentialPayload(source: source)
        let sealed = try CredentialEnvelope.seal(
            payload: payload,
            recipientPublicKey: recipientPublicKey,
            senderDeviceID: identity.id,
            recipientDeviceID: recipient.id
        )
        let token = try await accountStore.validAccessToken()
        let body = CredentialTransferCreateBody(
            ephemeralPublicKey: sealed.ephemeralPublicKey,
            nonce: sealed.nonce,
            ciphertext: sealed.ciphertext
        )
        let _: CredentialTransferDTO = try await api.send(
            path: "devices/\(recipient.id.uuidString)/transfers",
            body: body,
            accessToken: token
        )
    }

    func receivePending(accountStore: AccountStore) async throws -> Int {
        let token = try await accountStore.validAccessToken()
        let transfers: [CredentialTransferDTO] = try await api.send(
            path: "devices/me/transfers",
            accessToken: token
        )
        guard !transfers.isEmpty else { return 0 }

        let identity = try DeviceIdentityService.shared.loadOrCreate()
        let privateKey = try DeviceIdentityService.shared.loadPrivateKey()
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

            let _: EmptyResponse = try await api.send(
                path: "devices/me/transfers/\(transfer.id.uuidString)",
                method: "DELETE",
                accessToken: token
            )
            imported += 1
        }

        return imported
    }
}

private struct CredentialTransferCreateBody: Codable {
    let ephemeralPublicKey: String
    let nonce: String
    let ciphertext: String

    enum CodingKeys: String, CodingKey {
        case nonce, ciphertext
        case ephemeralPublicKey = "ephemeral_public_key"
    }
}
