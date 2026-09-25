import Foundation

enum DiagnosticCompatibility: String, Codable, Equatable {
    case compatible
    case compatibilityPlayer
    case unsupported
    case unknown
}

enum HealthLevel: String, Codable, Equatable {
    case stable
    case attention
    case critical
}

struct DiagnosticHealthInput: Equatable {
    let connectionSucceeded: Bool
    let responseTimeMs: Double?
    let startupLatencyMs: Double?
    let bufferingEvents: Int
    let compatibility: DiagnosticCompatibility
}

struct HealthScoreResult: Equatable {
    let score: Int
    let level: HealthLevel
    let reasons: [String]
}

enum DiagnosticErrorCategory: String, Codable, Equatable {
    case networkUnavailable
    case dnsFailure
    case timeout
    case authenticationFailed
    case notFound
    case malformedSource
    case unsupportedMedia
    case providerUnavailable
    case unknown
}

enum DiagnosticSeverity: String, Codable, Equatable {
    case info
    case warning
    case critical
}

struct DiagnosticIssue: Codable, Equatable, Identifiable {
    let id: UUID
    let severity: DiagnosticSeverity
    let title: String
    let detail: String

    init(id: UUID = UUID(), severity: DiagnosticSeverity, title: String, detail: String) {
        self.id = id
        self.severity = severity
        self.title = title
        self.detail = detail
    }
}

struct DiagnosticRecommendation: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let detail: String

    init(id: UUID = UUID(), title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

struct DiagnosticMetrics: Codable, Equatable {
    var responseTimeMs: Double?
    var startupLatencyMs: Double?
    var bitrateMbps: Double?
    var width: Int?
    var height: Int?
    var videoCodec: String?
    var audioCodec: String?
    var container: String?
    var bufferingEvents: Int
    var compatibility: DiagnosticCompatibility

    init(
        responseTimeMs: Double? = nil,
        startupLatencyMs: Double? = nil,
        bitrateMbps: Double? = nil,
        width: Int? = nil,
        height: Int? = nil,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        container: String? = nil,
        bufferingEvents: Int = 0,
        compatibility: DiagnosticCompatibility = .unknown
    ) {
        self.responseTimeMs = responseTimeMs
        self.startupLatencyMs = startupLatencyMs
        self.bitrateMbps = bitrateMbps
        self.width = width
        self.height = height
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.container = container
        self.bufferingEvents = bufferingEvents
        self.compatibility = compatibility
    }
}

struct DiagnosticSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let sourceID: UUID
    let checkedAt: Date
    let online: Bool
    let healthScore: Int
    let healthLevel: HealthLevel
    let metrics: DiagnosticMetrics
    let errorCategory: DiagnosticErrorCategory?
    let statusExplanation: String
    let issues: [DiagnosticIssue]
    let recommendations: [DiagnosticRecommendation]

    init(
        id: UUID = UUID(),
        sourceID: UUID,
        checkedAt: Date = Date(),
        online: Bool,
        healthScore: Int,
        healthLevel: HealthLevel,
        metrics: DiagnosticMetrics,
        errorCategory: DiagnosticErrorCategory? = nil,
        statusExplanation: String,
        issues: [DiagnosticIssue] = [],
        recommendations: [DiagnosticRecommendation] = []
    ) {
        self.id = id
        self.sourceID = sourceID
        self.checkedAt = checkedAt
        self.online = online
        self.healthScore = healthScore
        self.healthLevel = healthLevel
        self.metrics = metrics
        self.errorCategory = errorCategory
        self.statusExplanation = statusExplanation
        self.issues = issues
        self.recommendations = recommendations
    }
}
