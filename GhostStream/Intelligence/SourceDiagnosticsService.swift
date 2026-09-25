import Foundation

struct SourceDiagnosticsService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func diagnose(source: Source) async -> DiagnosticSnapshot {
        switch source.kind {
        case .xtream:
            return await diagnoseProvider(source)
        case .m3uURL:
            return await diagnoseRemotePlaylist(source)
        case .m3uText:
            return diagnoseLocalPlaylist(source)
        }
    }

    private func diagnoseProvider(_ source: Source) async -> DiagnosticSnapshot {
        guard let server = source.serverURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !server.isEmpty,
              let username = source.username,
              !username.isEmpty,
              let password = source.password,
              !password.isEmpty else {
            return failure(
                sourceID: source.id,
                category: .malformedSource,
                explanation: "Provider login is incomplete.",
                recommendation: "Edit this source and enter the provider server address, username, and password."
            )
        }

        let started = Date()
        do {
            let client = XtreamClient(serverURL: server, username: username, password: password)
            _ = try await client.authenticateResolved()
            let responseMs = Date().timeIntervalSince(started) * 1_000
            let metrics = DiagnosticMetrics(
                responseTimeMs: responseMs,
                compatibility: .unknown
            )
            return success(
                sourceID: source.id,
                metrics: metrics,
                explanation: "Provider authentication succeeded and the source is reachable."
            )
        } catch {
            return failure(
                sourceID: source.id,
                category: classify(error),
                explanation: diagnosticExplanation(for: error),
                recommendation: recommendation(for: error)
            )
        }
    }

    private func diagnoseRemotePlaylist(_ source: Source) async -> DiagnosticSnapshot {
        guard let raw = source.m3uURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return failure(
                sourceID: source.id,
                category: .malformedSource,
                explanation: "The playlist address is not a valid HTTP or HTTPS URL.",
                recommendation: "Edit this source and verify the playlist URL."
            )
        }

        do {
            let responseMs = try await measureReachability(url)
            let media = await MediaProbe.probe(url: url)
            let metrics = DiagnosticMetrics(
                responseTimeMs: responseMs,
                startupLatencyMs: media.startupLatencyMs,
                bitrateMbps: media.bitrateMbps,
                width: media.width,
                height: media.height,
                videoCodec: media.videoCodec,
                audioCodec: media.audioCodec,
                container: media.container,
                bufferingEvents: 0,
                compatibility: media.compatibility
            )
            return success(
                sourceID: source.id,
                metrics: metrics,
                explanation: "The playlist endpoint is reachable. Media compatibility was checked locally on this device."
            )
        } catch {
            return failure(
                sourceID: source.id,
                category: classify(error),
                explanation: diagnosticExplanation(for: error),
                recommendation: recommendation(for: error)
            )
        }
    }

    private func diagnoseLocalPlaylist(_ source: Source) -> DiagnosticSnapshot {
        let body = source.m3uText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard body.hasPrefix("#EXTM3U"), body.contains("#EXTINF") else {
            return failure(
                sourceID: source.id,
                category: .malformedSource,
                explanation: "The pasted playlist is missing required M3U playlist markers.",
                recommendation: "Replace the pasted data with a valid M3U playlist."
            )
        }

        let score = HealthScoreCalculator.score(
            DiagnosticHealthInput(
                connectionSucceeded: true,
                responseTimeMs: nil,
                startupLatencyMs: nil,
                bufferingEvents: 0,
                compatibility: .unknown
            )
        )
        return DiagnosticSnapshot(
            sourceID: source.id,
            online: true,
            healthScore: score.score,
            healthLevel: score.level,
            metrics: DiagnosticMetrics(compatibility: .unknown),
            statusExplanation: "The local playlist structure is valid. Network and codec checks begin when its streams are played.",
            recommendations: [
                DiagnosticRecommendation(
                    title: "Play a stream for deeper diagnostics",
                    detail: "GhostStream can measure startup latency, media format, and buffering only when a playable stream is opened."
                )
            ]
        )
    }

    private func measureReachability(_ url: URL) async throws -> Double {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("bytes=0-65535", forHTTPHeaderField: "Range")
        request.setValue("GhostStream/2.0", forHTTPHeaderField: "User-Agent")

        let started = Date()
        let (_, response) = try await session.data(for: request)
        let elapsed = Date().timeIntervalSince(started) * 1_000

        guard let http = response as? HTTPURLResponse else {
            throw DiagnosticNetworkError.invalidResponse
        }
        switch http.statusCode {
        case 200...299, 206:
            return elapsed
        case 401, 403:
            throw DiagnosticNetworkError.authenticationFailed
        case 404:
            throw DiagnosticNetworkError.notFound
        case 500...599:
            throw DiagnosticNetworkError.providerUnavailable
        default:
            throw DiagnosticNetworkError.http(http.statusCode)
        }
    }

    private func success(
        sourceID: UUID,
        metrics: DiagnosticMetrics,
        explanation: String
    ) -> DiagnosticSnapshot {
        let result = HealthScoreCalculator.score(
            DiagnosticHealthInput(
                connectionSucceeded: true,
                responseTimeMs: metrics.responseTimeMs,
                startupLatencyMs: metrics.startupLatencyMs,
                bufferingEvents: metrics.bufferingEvents,
                compatibility: metrics.compatibility
            )
        )

        let issues = result.level == .stable ? [] : [
            DiagnosticIssue(
                severity: result.level == .critical ? .critical : .warning,
                title: "Source health needs attention",
                detail: result.reasons.joined(separator: " ")
            )
        ]

        let recommendations = recommendationList(for: result, metrics: metrics)
        return DiagnosticSnapshot(
            sourceID: sourceID,
            online: true,
            healthScore: result.score,
            healthLevel: result.level,
            metrics: metrics,
            statusExplanation: explanation,
            issues: issues,
            recommendations: recommendations
        )
    }

    private func failure(
        sourceID: UUID,
        category: DiagnosticErrorCategory,
        explanation: String,
        recommendation: String
    ) -> DiagnosticSnapshot {
        let result = HealthScoreCalculator.score(
            DiagnosticHealthInput(
                connectionSucceeded: false,
                responseTimeMs: nil,
                startupLatencyMs: nil,
                bufferingEvents: 0,
                compatibility: .unknown
            )
        )

        return DiagnosticSnapshot(
            sourceID: sourceID,
            online: false,
            healthScore: result.score,
            healthLevel: result.level,
            metrics: DiagnosticMetrics(),
            errorCategory: category,
            statusExplanation: explanation,
            issues: [
                DiagnosticIssue(
                    severity: .critical,
                    title: categoryTitle(category),
                    detail: explanation
                )
            ],
            recommendations: [
                DiagnosticRecommendation(title: "Recommended action", detail: recommendation)
            ]
        )
    }

    private func recommendationList(
        for result: HealthScoreResult,
        metrics: DiagnosticMetrics
    ) -> [DiagnosticRecommendation] {
        var values: [DiagnosticRecommendation] = []

        if let response = metrics.responseTimeMs, response >= 750 {
            values.append(DiagnosticRecommendation(
                title: "Source is responding slowly",
                detail: "Retry the source when network conditions are better or test the same source on another trusted device."
            ))
        }
        if let latency = metrics.startupLatencyMs, latency >= 2_500 {
            values.append(DiagnosticRecommendation(
                title: "Playback startup is slow",
                detail: "Try GhostStream compatibility playback or compare the stream on another trusted device."
            ))
        }
        if metrics.bufferingEvents >= 3 {
            values.append(DiagnosticRecommendation(
                title: "Repeated buffering detected",
                detail: "Check the device network connection and compare playback on another trusted device."
            ))
        }
        if metrics.compatibility == .unsupported {
            values.append(DiagnosticRecommendation(
                title: "Media format is unsupported",
                detail: "Try GhostStream compatibility playback for this stream."
            ))
        }
        if values.isEmpty && result.level == .stable {
            values.append(DiagnosticRecommendation(
                title: "No corrective action needed",
                detail: "The checks completed without a major playback problem."
            ))
        }
        return values
    }

    private func classify(_ error: Error) -> DiagnosticErrorCategory {
        if let value = error as? DiagnosticNetworkError {
            switch value {
            case .authenticationFailed: return .authenticationFailed
            case .notFound: return .notFound
            case .providerUnavailable, .http, .invalidResponse: return .providerUnavailable
            }
        }
        if let value = error as? URLError {
            switch value.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                return .networkUnavailable
            case .cannotFindHost, .dnsLookupFailed:
                return .dnsFailure
            case .timedOut:
                return .timeout
            default:
                return .unknown
            }
        }
        if let value = error as? XtreamError {
            switch value {
            case .invalidURL: return .malformedSource
            case .authFailed: return .authenticationFailed
            case .timedOut: return .timeout
            case .hostNotFound: return .dnsFailure
            case .connectionFailed: return .networkUnavailable
            case .http(let code):
                if code == 401 || code == 403 { return .authenticationFailed }
                if code == 404 { return .notFound }
                if code >= 500 { return .providerUnavailable }
                return .unknown
            case .decoding: return .providerUnavailable
            case .network: return .networkUnavailable
            }
        }
        return .unknown
    }

    private func diagnosticExplanation(for error: Error) -> String {
        switch classify(error) {
        case .authenticationFailed: return "The source responded, but authentication was rejected."
        case .networkUnavailable: return "GhostStream could not establish a network connection to this source."
        case .dnsFailure: return "The source host name could not be resolved."
        case .timeout: return "The source did not respond before the diagnostic timeout."
        case .notFound: return "The requested source endpoint was not found."
        case .malformedSource: return "The source configuration is not valid."
        case .unsupportedMedia: return "The selected media format is not supported on this device."
        case .providerUnavailable: return "The source endpoint responded with an unavailable or invalid service response."
        case .unknown: return "GhostStream could not complete the source diagnostic."
        }
    }

    private func recommendation(for error: Error) -> String {
        switch classify(error) {
        case .authenticationFailed: return "Re-enter this source’s credentials and try again."
        case .networkUnavailable: return "Verify this device’s network connection, then retry."
        case .dnsFailure: return "Check the source server address for typing or DNS errors."
        case .timeout: return "Retry the source, then compare it on another trusted device if the timeout continues."
        case .notFound: return "Verify the source URL or provider server address."
        case .malformedSource: return "Edit the source and correct its URL or credentials."
        case .unsupportedMedia: return "Try GhostStream compatibility playback."
        case .providerUnavailable: return "Retry later or verify the provider endpoint from the source settings."
        case .unknown: return "Retry the diagnostic and review the source settings if the problem continues."
        }
    }

    private func categoryTitle(_ category: DiagnosticErrorCategory) -> String {
        switch category {
        case .networkUnavailable: return "Network unavailable"
        case .dnsFailure: return "Host not found"
        case .timeout: return "Source timed out"
        case .authenticationFailed: return "Authentication failed"
        case .notFound: return "Source not found"
        case .malformedSource: return "Invalid source"
        case .unsupportedMedia: return "Unsupported media"
        case .providerUnavailable: return "Source unavailable"
        case .unknown: return "Diagnostic failed"
        }
    }
}

private enum DiagnosticNetworkError: Error {
    case invalidResponse
    case authenticationFailed
    case notFound
    case providerUnavailable
    case http(Int)
}
