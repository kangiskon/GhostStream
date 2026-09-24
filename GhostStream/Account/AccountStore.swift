import Combine
import Foundation
import UIKit

@MainActor
final class AccountStore: ObservableObject {
    enum Status: Equatable {
        case signedOut
        case restoring
        case working
        case awaitingEmailVerification(String)
        case signedIn
        case error(String)
    }

    enum SyncState: Equatable {
        case idle
        case syncing
        case offline
        case failed(String)
    }

    @Published private(set) var status: Status = .signedOut
    @Published private(set) var account: AccountDTO?
    @Published private(set) var devices: [DeviceDTO] = []
    @Published private(set) var syncState: SyncState = .idle

    private let api: GhostStreamAPIClient
    private let identityService: DeviceIdentityService
    private var accessToken: String?
    private var refreshTask: Task<TokenPairDTO, Error>?

    init(
        api: GhostStreamAPIClient = GhostStreamAPIClient(),
        identityService: DeviceIdentityService = .shared
    ) {
        self.api = api
        self.identityService = identityService
    }

    var isSignedIn: Bool {
        if case .signedIn = status { return true }
        return false
    }

    var currentAccessToken: String? {
        accessToken
    }

    func register(email: String, password: String) async {
        status = .working
        do {
            let device = try deviceContext()
            let body = RegisterBody(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                password: password,
                deviceID: device.identity.id,
                displayName: device.displayName,
                platform: device.platform,
                osVersion: device.osVersion,
                publicKey: device.identity.publicKeyBase64
            )
            let response: VerificationResponse = try await api.send(path: "auth/register", body: body)
            guard response.verificationRequired else {
                throw APIError.invalidResponse
            }
            status = .awaitingEmailVerification(body.email)
        } catch {
            handle(error)
        }
    }

    func signIn(email: String, password: String) async {
        status = .working
        do {
            let device = try deviceContext()
            let body = LoginBody(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                password: password,
                deviceID: device.identity.id,
                displayName: device.displayName,
                platform: device.platform,
                osVersion: device.osVersion,
                publicKey: device.identity.publicKeyBase64
            )
            let pair: TokenPairDTO = try await api.send(path: "auth/login", body: body)
            try await accept(pair: pair)
        } catch {
            handle(error)
        }
    }

    func signInWithApple(identityToken: String, authorizationCode: String?) async {
        status = .working
        do {
            let device = try deviceContext()
            let body = AppleLoginBody(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                deviceID: device.identity.id,
                displayName: device.displayName,
                platform: device.platform,
                osVersion: device.osVersion,
                publicKey: device.identity.publicKeyBase64
            )
            let pair: TokenPairDTO = try await api.send(path: "auth/apple", body: body)
            try await accept(pair: pair)
        } catch {
            handle(error)
        }
    }

    func requestPasswordReset(email: String) async {
        do {
            let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let _: AcceptedResponse = try await api.send(path: "auth/forgot-password", body: EmailBody(email: normalized))
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func restoreSession() async {
        guard SessionVault.readRefreshToken() != nil,
              SessionVault.readAccountID() != nil else {
            status = .signedOut
            return
        }
        status = .restoring
        do {
            let pair = try await refreshSession()
            accessToken = pair.accessToken
            try await loadAccountAndDevices()
            status = .signedIn
        } catch {
            if let apiError = error as? APIError,
               apiError == .accountDeleted || apiError == .unauthorized {
                clearLocalSession()
            } else {
                status = .error(error.localizedDescription)
            }
        }
    }

    func refreshSession() async throws -> TokenPairDTO {
        if let refreshTask {
            return try await refreshTask.value
        }
        guard let refreshToken = SessionVault.readRefreshToken(),
              let accountID = SessionVault.readAccountID() else {
            throw APIError.unauthorized
        }

        let api = self.api
        let task = Task<TokenPairDTO, Error> {
            let pair: TokenPairDTO = try await api.send(
                path: "auth/refresh",
                body: RefreshBody(refreshToken: refreshToken)
            )
            return pair
        }
        refreshTask = task
        defer { refreshTask = nil }

        let pair = try await task.value
        try SessionVault.saveRefreshToken(pair.refreshToken, accountID: accountID)
        accessToken = pair.accessToken
        return pair
    }

    func validAccessToken() async throws -> String {
        if let accessToken {
            return accessToken
        }
        _ = try await refreshSession()
        guard let accessToken else { throw APIError.unauthorized }
        return accessToken
    }

    func updateSyncState(_ state: SyncState) {
        syncState = state
    }

    func reloadDevices() async {
        guard accessToken != nil else { return }
        do {
            try await loadDevices()
        } catch {
            syncState = .failed(error.localizedDescription)
        }
    }

    func signOut() async {
        let refreshToken = SessionVault.readRefreshToken()
        if let refreshToken {
            let _: EmptyResponse? = try? await api.send(
                path: "auth/logout",
                body: RefreshBody(refreshToken: refreshToken)
            )
        }
        clearLocalSession()
    }

    private func accept(pair: TokenPairDTO) async throws {
        accessToken = pair.accessToken
        try await loadAccountAndDevices()
        guard let account else { throw APIError.invalidResponse }
        try SessionVault.saveRefreshToken(pair.refreshToken, accountID: account.id)
        status = .signedIn
    }

    private func loadAccountAndDevices() async throws {
        guard let accessToken else { throw APIError.unauthorized }
        let state: AccountStateResponse = try await api.send(path: "account/state", accessToken: accessToken)
        guard let accountID = UUID(uuidString: state.accountID) else {
            throw APIError.invalidResponse
        }
        account = AccountDTO(
            id: accountID,
            email: state.email,
            emailVerified: state.emailVerified,
            createdAt: nil
        )
        try await loadDevices()
    }

    private func loadDevices() async throws {
        guard let accessToken else { throw APIError.unauthorized }
        let response: [DeviceDTO] = try await api.send(path: "devices", accessToken: accessToken)
        devices = response
    }

    private func deviceContext() throws -> DeviceContext {
        let identity = try identityService.loadOrCreate()
        let device = UIDevice.current
        let platform = device.userInterfaceIdiom == .pad ? "ipados" : "ios"
        return DeviceContext(
            identity: identity,
            displayName: device.name,
            platform: platform,
            osVersion: device.systemVersion
        )
    }

    private func clearLocalSession() {
        accessToken = nil
        account = nil
        devices = []
        syncState = .idle
        SessionVault.clear()
        status = .signedOut
    }

    private func handle(_ error: Error) {
        if let apiError = error as? APIError, apiError == .accountDeleted {
            clearLocalSession()
            return
        }
        status = .error(error.localizedDescription)
    }
}

private struct DeviceContext {
    let identity: DeviceIdentity
    let displayName: String
    let platform: String
    let osVersion: String
}

private struct RegisterBody: Codable {
    let email: String
    let password: String
    let deviceID: UUID
    let displayName: String
    let platform: String
    let osVersion: String
    let publicKey: String

    enum CodingKeys: String, CodingKey {
        case email, password, platform
        case deviceID = "device_id"
        case displayName = "display_name"
        case osVersion = "os_version"
        case publicKey = "public_key"
    }
}

private struct LoginBody: Codable {
    let email: String
    let password: String
    let deviceID: UUID
    let displayName: String
    let platform: String
    let osVersion: String
    let publicKey: String

    enum CodingKeys: String, CodingKey {
        case email, password, platform
        case deviceID = "device_id"
        case displayName = "display_name"
        case osVersion = "os_version"
        case publicKey = "public_key"
    }
}

private struct AppleLoginBody: Codable {
    let identityToken: String
    let authorizationCode: String?
    let deviceID: UUID
    let displayName: String
    let platform: String
    let osVersion: String
    let publicKey: String

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case authorizationCode = "authorization_code"
        case deviceID = "device_id"
        case displayName = "display_name"
        case platform
        case osVersion = "os_version"
        case publicKey = "public_key"
    }
}

private struct RefreshBody: Codable {
    let refreshToken: String
    enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
}

private struct EmailBody: Codable {
    let email: String
}

private struct VerificationResponse: Codable {
    let verificationRequired: Bool
    enum CodingKeys: String, CodingKey { case verificationRequired = "verification_required" }
}

private struct AcceptedResponse: Codable {
    let accepted: Bool
}

private struct AccountStateResponse: Codable {
    let state: String
    let accountID: String
    let email: String
    let emailVerified: Bool

    enum CodingKeys: String, CodingKey {
        case state, email
        case accountID = "account_id"
        case emailVerified = "email_verified"
    }
}
