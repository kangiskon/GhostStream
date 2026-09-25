import Foundation

enum HealthScoreCalculator {
    static func score(_ input: DiagnosticHealthInput) -> HealthScoreResult {
        guard input.connectionSucceeded else {
            return HealthScoreResult(
                score: 0,
                level: .critical,
                reasons: ["Source could not be reached, so playback health cannot be established."]
            )
        }

        var score = 100
        var reasons: [String] = []
        var hasPenalty = false

        if let response = input.responseTimeMs {
            switch response {
            case ..<0:
                score -= 10
                hasPenalty = true
                reasons.append("Response timing was invalid and was ignored.")
            case 0..<350:
                reasons.append("Source response time is stable.")
            case 350..<750:
                score -= 5
                hasPenalty = true
                reasons.append("Source response time is slightly elevated.")
            case 750..<1_500:
                score -= 12
                hasPenalty = true
                reasons.append("Source response time is slow.")
            default:
                score -= 25
                hasPenalty = true
                reasons.append("Source response time is very slow.")
            }
        } else {
            score -= 5
            hasPenalty = true
            reasons.append("Response time could not be measured.")
        }

        if let startup = input.startupLatencyMs {
            switch startup {
            case ..<0:
                score -= 10
                hasPenalty = true
                reasons.append("Stream startup timing was invalid and was ignored.")
            case 0..<1_000:
                reasons.append("Stream startup latency is stable.")
            case 1_000..<2_500:
                score -= 6
                hasPenalty = true
                reasons.append("Stream startup is somewhat delayed.")
            case 2_500..<5_000:
                score -= 14
                hasPenalty = true
                reasons.append("Stream startup is slow.")
            default:
                score -= 24
                hasPenalty = true
                reasons.append("Stream startup is very slow.")
            }
        }

        let buffering = max(0, input.bufferingEvents)
        if buffering == 0 {
            reasons.append("No buffering events were observed.")
        } else if buffering <= 2 {
            score -= buffering * 5
            hasPenalty = true
            reasons.append("A small number of buffering events were observed.")
        } else if buffering <= 5 {
            score -= 16
            hasPenalty = true
            reasons.append("Repeated buffering reduced source health.")
        } else {
            score -= 28
            hasPenalty = true
            reasons.append("Frequent buffering indicates unstable playback.")
        }

        switch input.compatibility {
        case .compatible:
            reasons.append("Media format is compatible with this device.")
        case .compatibilityPlayer:
            score -= 8
            hasPenalty = true
            reasons.append("Playback requires GhostStream compatibility mode.")
        case .unsupported:
            score -= 40
            hasPenalty = true
            reasons.append("Media format is unsupported on this device.")
        case .unknown:
            score -= 5
            hasPenalty = true
            reasons.append("Media compatibility has not been fully determined.")
        }

        score = min(100, max(0, score))

        let level: HealthLevel
        switch score {
        case 80...100: level = .stable
        case 45..<80: level = .attention
        default: level = .critical
        }

        if !hasPenalty && level == .stable {
            reasons.insert("Connection is stable and no major playback problems were detected.", at: 0)
        }

        return HealthScoreResult(score: score, level: level, reasons: reasons)
    }
}
