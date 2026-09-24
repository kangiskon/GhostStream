import Foundation

struct DeviceIdentity: Equatable {
    let id: UUID
    let publicKey: Data

    var publicKeyBase64: String {
        publicKey.base64EncodedString()
    }
}

enum GhostDevicePlatform: String, Codable {
    case iOS = "ios"
    case iPadOS = "ipados"
    case tvOS = "tvos"
}
