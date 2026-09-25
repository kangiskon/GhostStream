import Foundation

actor TVSyncService {
    static let shared = TVSyncService()

    private let baseURL = URL(string: "https://ghoststreams.ink/api/v1")!
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func pullProgress() async throws {
        let token = try await TVPairingService.shared.validAccessToken()
        let values: [TVPlaybackProgressRecord] = try await request(
            path: "activity",
            method: "GET",
            accessToken: token,
            body: Optional<String>.none
        )
        await MainActor.run {
            for item in values {
                TVPlaybackProgressStore.shared.applyRemote(item)
            }
        }
    }

    func push(_ record: TVPlaybackProgressRecord) async throws {
        let token = try await TVPairingService().validAccessToken()
        let _: TVSyncPushAck = try await request(
            path: "sync/push",
            method: "POST",
            accessToken: token,
            body: TVSyncPushBody(progress: [record])
        )
    }

    func clearLocalState() async {
        await MainActor.run {
            TVPlaybackProgressStore.shared.clearAll()
        }
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
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TVPairingError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? decoder.decode(TVSyncErrorEnvelope.self, from: data)
            if http.statusCode == 410, envelope?.detail?.code == "account_deleted" {
                await MainActor.run {
                    TVSessionVault.clear()
                    TVDeviceIdentityStore.shared.clear()
                    TVPlaybackProgressStore.shared.clearAll()
                    SourceStore.shared.wipeAllLocalData()
                }
            }
            throw TVPairingError.server(http.statusCode, envelope?.detail?.code)
        }

        return try decoder.decode(Response.self, from: data)
    }
}

private struct TVSyncPushBody: Codable {
    let favorites: [String] = []
    let progress: [TVPlaybackProgressRecord]
    let sources: [String] = []
    let diagnostics: [String] = []
}

private struct TVSyncPushAck: Codable {
    let cursor: Int
}

private struct TVSyncErrorEnvelope: Codable {
    let detail: TVSyncErrorDetail?
}

private struct TVSyncErrorDetail: Codable {
    let code: String?
}
