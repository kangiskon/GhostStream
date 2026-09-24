import Foundation

enum APIError: Error, LocalizedError, Equatable {
    case invalidResponse
    case accountDeleted
    case unauthorized
    case server(statusCode: Int, code: String?, message: String?)
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GhostStream received an invalid server response."
        case .accountDeleted:
            return "This GhostStream account has been deleted."
        case .unauthorized:
            return "Your GhostStream session is no longer valid."
        case .server(_, _, let message):
            return message ?? "GhostStream could not complete the request."
        case .transport(let message), .decoding(let message):
            return message
        }
    }
}
