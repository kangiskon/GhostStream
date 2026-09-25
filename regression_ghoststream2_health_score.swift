import Foundation

@main
struct HealthScoreRegression {
    static func main() {
        let stable = HealthScoreCalculator.score(
            DiagnosticHealthInput(
                connectionSucceeded: true,
                responseTimeMs: 120,
                startupLatencyMs: 350,
                bufferingEvents: 0,
                compatibility: .compatible
            )
        )
        precondition(stable.score >= 90)
        precondition(stable.reasons.contains(where: { $0.lowercased().contains("stable") }))

        let buffering = HealthScoreCalculator.score(
            DiagnosticHealthInput(
                connectionSucceeded: true,
                responseTimeMs: 120,
                startupLatencyMs: 350,
                bufferingEvents: 6,
                compatibility: .compatible
            )
        )
        precondition(buffering.score < stable.score)

        let unsupported = HealthScoreCalculator.score(
            DiagnosticHealthInput(
                connectionSucceeded: true,
                responseTimeMs: 120,
                startupLatencyMs: 350,
                bufferingEvents: 0,
                compatibility: .unsupported
            )
        )
        precondition(unsupported.score < stable.score)
        precondition(unsupported.reasons.contains(where: { $0.lowercased().contains("unsupported") }))

        let failed = HealthScoreCalculator.score(
            DiagnosticHealthInput(
                connectionSucceeded: false,
                responseTimeMs: nil,
                startupLatencyMs: nil,
                bufferingEvents: 0,
                compatibility: .unknown
            )
        )
        precondition(failed.score == 0)
        precondition(failed.level == .critical)

        let clamped = HealthScoreCalculator.score(
            DiagnosticHealthInput(
                connectionSucceeded: true,
                responseTimeMs: 99_999,
                startupLatencyMs: 99_999,
                bufferingEvents: 999,
                compatibility: .unsupported
            )
        )
        precondition((0...100).contains(clamped.score))

        print("ghoststream2 health score regression: PASS")
    }
}
