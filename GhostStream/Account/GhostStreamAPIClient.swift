import Foundation

protocol GhostStreamAPITransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionGhostStreamTransport: GhostStreamAPITransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return (data, http)
    }
}

actor GhostStreamAPIClient {
    static let productionBaseURL = URL(string: "https://ghoststreams.ink/api/v1")!

    private let baseURL: URL
    private let transport: any GhostStreamAPITransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL = GhostStreamAPIClient.productionBaseURL,
        transport: any GhostStreamAPITransport = URLSessionGhostStreamTransport()
    ) {
        self.baseURL = baseURL
        self.transport = transport

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func send<Response: Decodable>(
        path: String,
        method: String = "GET",
        accessToken: String? = nil
    ) async throws -> Response {
        try await send(path: path, method: method, body: Optional<String>.none, accessToken: accessToken)
    }

    func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String = "POST",
        body: Body?,
        accessToken: String? = nil
    ) async throws -> Response {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let parts = cleanPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let pathPart = String(parts[0])
        var url = baseURL
        for segment in pathPart.split(separator: "/", omittingEmptySubsequences: true) {
            url.appendPathComponent(String(segment))
        }
        if parts.count == 2 {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw APIError.invalidResponse
            }
            components.percentEncodedQuery = String(parts[1])
            guard let queryURL = components.url else {
                throw APIError.invalidResponse
            }
            url = queryURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard (200..<300).contains(response.statusCode) else {
            let envelope = try? decoder.decode(APIErrorResponse.self, from: data)
            let code = envelope?.detail?.code
            let message = envelope?.detail?.message
            if response.statusCode == 410 && code == "account_deleted" {
                throw APIError.accountDeleted
            }
            if response.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.server(statusCode: response.statusCode, code: code, message: message)
        }

        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}

struct EmptyResponse: Codable, Equatable {
    init() {}
}
