import CryptoKit
import Foundation

@main
struct CredentialEnvelopeRegression {
    static func main() throws {
        let recipient = Curve25519.KeyAgreement.PrivateKey()
        let wrongRecipient = Curve25519.KeyAgreement.PrivateKey()
        let senderDeviceID = UUID()
        let recipientDeviceID = UUID()

        let source = Source(
            name: "Regression Source",
            kind: .xtream,
            serverURL: "https://provider.example",
            username: "review-user",
            password: "review-password"
        )
        let payload = CredentialPayload(source: source)
        let envelope = try CredentialEnvelope.seal(
            payload: payload,
            recipientPublicKey: recipient.publicKey.rawRepresentation,
            senderDeviceID: senderDeviceID,
            recipientDeviceID: recipientDeviceID
        )

        let opened = try CredentialEnvelope.open(
            envelope,
            recipientPrivateKey: recipient,
            expectedRecipientDeviceID: recipientDeviceID
        )
        precondition(opened == payload)

        do {
            _ = try CredentialEnvelope.open(
                envelope,
                recipientPrivateKey: wrongRecipient,
                expectedRecipientDeviceID: recipientDeviceID
            )
            fatalError("wrong private key unexpectedly decrypted credential payload")
        } catch {
            print("wrong private key rejected")
        }
    }
}
