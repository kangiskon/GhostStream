import AVFoundation
import CoreMedia
import Foundation

struct MediaProbeResult: Equatable {
    let startupLatencyMs: Double?
    let bitrateMbps: Double?
    let width: Int?
    let height: Int?
    let videoCodec: String?
    let audioCodec: String?
    let container: String?
    let compatibility: DiagnosticCompatibility
}

enum MediaProbe {
    static func probe(url: URL) async -> MediaProbeResult {
        let started = Date()
        let asset = AVURLAsset(url: url)

        do {
            let playable = try await asset.load(.isPlayable)
            guard playable else {
                return MediaProbeResult(
                    startupLatencyMs: nil,
                    bitrateMbps: nil,
                    width: nil,
                    height: nil,
                    videoCodec: nil,
                    audioCodec: nil,
                    container: normalizedContainer(url),
                    compatibility: .unsupported
                )
            }

            async let videoTracksTask = asset.loadTracks(withMediaType: .video)
            async let audioTracksTask = asset.loadTracks(withMediaType: .audio)
            let (videoTracks, audioTracks) = try await (videoTracksTask, audioTracksTask)

            let startup = Date().timeIntervalSince(started) * 1_000
            let videoTrack = videoTracks.first
            let audioTrack = audioTracks.first

            var width: Int?
            var height: Int?
            var bitrateMbps: Double?
            var videoCodec: String?
            var audioCodec: String?

            if let videoTrack {
                let size = try? await videoTrack.load(.naturalSize)
                if let size {
                    width = Int(abs(size.width.rounded()))
                    height = Int(abs(size.height.rounded()))
                }

                if let rate = try? await videoTrack.load(.estimatedDataRate), rate > 0 {
                    bitrateMbps = Double(rate) / 1_000_000
                }

                if let descriptions = try? await videoTrack.load(.formatDescriptions),
                   let description = descriptions.first {
                    videoCodec = codecName(CMFormatDescriptionGetMediaSubType(description))
                }
            }

            if let audioTrack,
               let descriptions = try? await audioTrack.load(.formatDescriptions),
               let description = descriptions.first {
                audioCodec = codecName(CMFormatDescriptionGetMediaSubType(description))
            }

            let hasMedia = videoTrack != nil || audioTrack != nil
            return MediaProbeResult(
                startupLatencyMs: startup,
                bitrateMbps: bitrateMbps,
                width: width,
                height: height,
                videoCodec: videoCodec,
                audioCodec: audioCodec,
                container: normalizedContainer(url),
                compatibility: hasMedia ? .compatible : .unknown
            )
        } catch {
            return MediaProbeResult(
                startupLatencyMs: nil,
                bitrateMbps: nil,
                width: nil,
                height: nil,
                videoCodec: nil,
                audioCodec: nil,
                container: normalizedContainer(url),
                compatibility: .unknown
            )
        }
    }

    private static func normalizedContainer(_ url: URL) -> String? {
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !ext.isEmpty else { return nil }
        switch ext {
        case "m3u8": return "HLS"
        case "ts": return "MPEG-TS"
        case "mp4", "m4v": return "MP4"
        case "mkv": return "Matroska"
        case "webm": return "WebM"
        default: return ext.uppercased()
        }
    }

    private static func codecName(_ value: FourCharCode) -> String {
        switch value {
        case kCMVideoCodecType_H264: return "H.264"
        case kCMVideoCodecType_HEVC: return "HEVC"
        case kCMVideoCodecType_JPEG: return "JPEG"
        case FourCharCode(0x6D703461): return "AAC" // 'mp4a'
        case FourCharCode(0x61616368): return "HE-AAC" // 'aach'
        default:
            let bytes: [UInt8] = [
                UInt8((value >> 24) & 0xff),
                UInt8((value >> 16) & 0xff),
                UInt8((value >> 8) & 0xff),
                UInt8(value & 0xff),
            ]
            return String(bytes: bytes, encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? String(value)
        }
    }
}
