import Foundation
import UIKit

struct DiagnosticSnapshotDTO: Codable, Equatable {
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
        case width, height, container
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
        case compatibility
        case createdAt = "created_at"
    }
}

enum DiagnosticSanitizer {
    static func sanitize(_ snapshot: DiagnosticSnapshot) -> DiagnosticSnapshotDTO {
        DiagnosticSnapshotDTO(
            sourceID: snapshot.sourceID,
            deviceClass: deviceClass,
            healthScore: snapshot.healthScore,
            responseTimeMs: finite(snapshot.metrics.responseTimeMs),
            latencyMs: finite(snapshot.metrics.startupLatencyMs),
            bitrateMbps: finite(snapshot.metrics.bitrateMbps),
            width: snapshot.metrics.width,
            height: snapshot.metrics.height,
            videoCodec: trimmed(snapshot.metrics.videoCodec),
            audioCodec: trimmed(snapshot.metrics.audioCodec),
            container: trimmed(snapshot.metrics.container),
            bufferingEvents: max(0, snapshot.metrics.bufferingEvents),
            errorCategory: snapshot.errorCategory?.rawValue,
            compatibility: snapshot.metrics.compatibility.rawValue,
            createdAt: snapshot.checkedAt
        )
    }

    private static var deviceClass: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: return "ipad"
        case .phone: return "iphone"
        default: return "apple-device"
        }
    }

    private static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : String(clean.prefix(80))
    }
}
