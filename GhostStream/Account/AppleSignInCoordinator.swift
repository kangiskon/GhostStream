import AuthenticationServices
import Foundation

enum AppleSignInError: LocalizedError {
    case missingCredential
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            return "GhostStream could not read the Sign in with Apple credential."
        case .missingIdentityToken:
            return "Sign in with Apple did not return an identity token."
        }
    }
}

struct AppleSignInPayload {
    let identityToken: String
    let authorizationCode: String?
}

enum AppleSignInCoordinator {
    static func payload(from result: Result<ASAuthorization, Error>) throws -> AppleSignInPayload {
        let authorization = try result.get()
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppleSignInError.missingCredential
        }
        return try payload(from: credential)
    }

    static func payload(from credential: ASAuthorizationAppleIDCredential) throws -> AppleSignInPayload {
        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8),
              !identityToken.isEmpty else {
            throw AppleSignInError.missingIdentityToken
        }
        let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        return AppleSignInPayload(identityToken: identityToken, authorizationCode: code)
    }
}
