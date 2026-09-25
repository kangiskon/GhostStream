import CryptoKit
import Foundation

struct CredentialPayload: Codable, Equatable {
    let sourceID: UUID
    let name: String
    let kind: String
    let m3uURL: String?
    let m3uText: String?
    let serverURL: String?
    let username: String?
    let password: String?
    let epgURL: String?

    init(source: Source) {
        sourceID = source.id
        name = source.name
        kind = source.kind.rawValue
        m3uURL = source.m3uURL
        m3uText = source.m3uText
        serverURL = source.serverURL
        username = source.username
        password = source.password
        epgURL = source.epgURL
    }

    func makeSource() throws -> Source {
        guard let sourceKind = Source.Kind(rawValue: kind) else {
            throw CredentialEnvelopeError.invalidPayload
        }
        return Source(
            id: sourceID,
            name: name,
            kind: sourceKind,
            m3uURL: m3uURL,
            m3uText: m3uText,
            serverURL: serverURL,
            username: username,
            password: password,
            epgURL: epgURL
        )
    }
}

struct SealedCredentialEnvelope: Codable, Equatable {
    let senderDeviceID: UUID
    let recipientDeviceID: UUID
    let ephemeralPublicKey: String
    let nonce: String
    let ciphertext: String

    enum CodingKeys: String, CodingKey {
        case ciphertext, nonce
        case senderDeviceID = "sender_device_id"
        case recipientDeviceID = "recipient_device_id"
        case ephemeralPublicKey = "ephemeral_public_key"
    }
}

enum CredentialEnvelopeError: LocalizedError {
    case invalidPublicKey
    case invalidEncoding
    case invalidPayload
    case wrongRecipient

    var errorDescription: String? {
        switch self {
        case .invalidPublicKey: return "The destination device key is invalid."
        case .invalidEncoding: return "The encrypted source package is invalid."
        case .invalidPayload: return "The source package could not be decoded."
        case .wrongRecipient: return "This encrypted source package belongs to another device."
        }
    }
}

enum CredentialEnvelope {
    private static let salt = Data("GhostStream/CredentialTransfer/v1".utf8)
    private static let tagLength = 16

    static func authenticatedData(senderDeviceID: UUID, recipientDeviceID: UUID) -> Data {
        Data("GhostStream/CredentialTransfer/v1|\(senderDeviceID.uuidString)|\(recipientDeviceID.uuidString)".utf8)
    }

    static func seal(
        payload: CredentialPayload,
        recipientPublicKey: Data,
        senderDeviceID: UUID,
        recipientDeviceID: UUID
    ) throws -> SealedCredentialEnvelope {
        let recipientKey: Curve25519.KeyAgreement.PublicKey
        do {
            recipientKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipientPublicKey)
        } catch {
            throw CredentialEnvelopeError.invalidPublicKey
        }

        let ephemeralPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        let sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: recipientKey)
        let aad = authenticatedData(senderDeviceID: senderDeviceID, recipientDeviceID: recipientDeviceID)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: aad,
            outputByteCount: 32
        )

        let encoded = try JSONEncoder().encode(payload)
        let sealedBox = try ChaChaPoly.seal(encoded, using: symmetricKey, authenticating: aad)
        let nonceData = sealedBox.nonce.withUnsafeBytes { Data($0) }
        let cipherAndTag = sealedBox.ciphertext + sealedBox.tag

        return SealedCredentialEnvelope(
            senderDeviceID: senderDeviceID,
            recipientDeviceID: recipientDeviceID,
            ephemeralPublicKey: ephemeralPrivateKey.publicKey.rawRepresentation.base64EncodedString(),
            nonce: nonceData.base64EncodedString(),
            ciphertext: cipherAndTag.base64EncodedString()
        )
    }

    static func open(
        _ envelope: SealedCredentialEnvelope,
        recipientPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        expectedRecipientDeviceID: UUID? = nil
    ) throws -> CredentialPayload {
        if let expectedRecipientDeviceID, envelope.recipientDeviceID != expectedRecipientDeviceID {
            throw CredentialEnvelopeError.wrongRecipient
        }

        guard let ephemeralData = Data(base64Encoded: envelope.ephemeralPublicKey),
              let nonceData = Data(base64Encoded: envelope.nonce),
              let cipherAndTag = Data(base64Encoded: envelope.ciphertext),
              cipherAndTag.count > tagLength else {
            throw CredentialEnvelopeError.invalidEncoding
        }

        let ephemeralPublicKey: Curve25519.KeyAgreement.PublicKey
        do {
            ephemeralPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralData)
        } catch {
            throw CredentialEnvelopeError.invalidPublicKey
        }

        let sharedSecret = try recipientPrivateKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey)
        let aad = authenticatedData(
            senderDeviceID: envelope.senderDeviceID,
            recipientDeviceID: envelope.recipientDeviceID
        )
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: aad,
            outputByteCount: 32
        )

        let nonce = try ChaChaPoly.Nonce(data: nonceData)
        let ciphertext = cipherAndTag.dropLast(tagLength)
        let tag = cipherAndTag.suffix(tagLength)
        let sealedBox = try ChaChaPoly.SealedBox(
            nonce: nonce,
            ciphertext: Data(ciphertext),
            tag: Data(tag)
        )
        let plaintext = try ChaChaPoly.open(sealedBox, using: symmetricKey, authenticating: aad)
        do {
            return try JSONDecoder().decode(CredentialPayload.self, from: plaintext)
        } catch {
            throw CredentialEnvelopeError.invalidPayload
        }
    }
}
