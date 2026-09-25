import Foundation

actor TVSyncService {
    static let shared = TVSyncService()

    private let baseURL = URL(string: "https://ghoststreams.ink/api/v1")!
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
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
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func fetchDevices() async throws -> [TVAccountDeviceDTO] {
        let token = try await TVPairingService.shared.validAccessToken()
        return try await request(
            path: "devices",
            method: "GET",
            accessToken: token,
            body: Optional<String>.none
        )
    }

    func fetchDiagnostics(sourceID: UUID) async throws -> [TVDiagnosticSummaryDTO] {
        let token = try await TVPairingService.shared.validAccessToken()
        return try await request(
            path: "diagnostics/\(sourceID.uuidString)",
            method: "GET",
            accessToken: token,
            body: Optional<String>.none
        )
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


struct TVAccountDeviceDTO: Codable, Equatable, Identifiable {
    let id: UUID
    let displayName: String
    let platform: String
    let osVersion: String
    let publicKey: String
    let trustState: String
    let lastSeenAt: Date
    let revokedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, platform
        case displayName = "display_name"
        case osVersion = "os_version"
        case publicKey = "public_key"
        case trustState = "trust_state"
        case lastSeenAt = "last_seen_at"
        case revokedAt = "revoked_at"
    }
}

struct TVDiagnosticSummaryDTO: Codable, Equatable, Identifiable {
    let id: UUID
    let sourceID: UUID
    let deviceClass: String
    let healthScore: Int
    let responseTimeMs: Double?
    let latencyMs: Double?
    let bitrateMbps: Double?
    let width: Int?
    let height: Int?
    let videoCodec: String?
    let audioCodec: String?
    let container: String?
    let bufferingEvents: Int
    let errorCategory: String?
    let compatibility: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, width, height, container, compatibility
        case sourceID = "source_id"
        case deviceClass = "device_class"
        case healthScore = "health_score"
        case responseTimeMs = "response_time_ms"
        case latencyMs = "latency_ms"
        case bitrateMbps = "bitrate_mbps"
        case videoCodec = "video_codec"
        case audioCodec = "audio_codec"
        case bufferingEvents = "buffering_events"
        case errorCategory = "error_category"
        case createdAt = "created_at"
    }
}
