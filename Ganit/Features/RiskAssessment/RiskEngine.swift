import Foundation

// MARK: - Risk Engine

/// Session-level behavioral pattern aggregation for disorder screening.
/// Operates post-session, not per-question.
class RiskEngine {

    private let storage: EncryptedStorage
    private let minimumSessions = 10

    init(storage: EncryptedStorage = .shared) {
        self.storage = storage
    }

    /// Evaluate screening after a session completes.
    func evaluate(sessions: [SessionRecord], userGroup: UserGroup) -> [ScreeningResult] {
        guard sessions.count >= minimumSessions else {
            return ScreeningCondition.allCases.map { condition in
                ScreeningResult(
                    condition: condition,
                    indicatorScore: 0,
                    confidence: 0,
                    indicators: [],
                    sessionCount: sessions.count
                )
            }
        }

        var results: [ScreeningResult] = []

        switch userGroup {
        case .child:
            results.append(screenForDyscalculia(sessions: sessions))
            results.append(screenForADHD(sessions: sessions))
        case .elderly:
            results.append(screenForCognitiveDecline(sessions: sessions))
        }

        return results
    }

    // MARK: - Dyscalculia Screening

    private func screenForDyscalculia(sessions: [SessionRecord]) -> ScreeningResult {
        var indicators: [IndicatorDetail] = []
        var totalScore: Float = 0

        // Indicator 1: Consistent difficulty with number magnitude
        let mathSessions = sessions.filter { $0.quizMode != nil }
        let avgAccuracy = mathSessions.isEmpty ? 0.5 : mathSessions.map(\.accuracy).reduce(0, +) / Double(mathSessions.count)
        if avgAccuracy < 0.4 {
            let score: Float = Float(1.0 - avgAccuracy)
            indicators.append(IndicatorDetail(
                name: "Low Math Accuracy",
                description: "Consistently scoring below expected levels on math questions",
                score: score,
                dataPoints: mathSessions.count
            ))
            totalScore += score
        }

        // Indicator 2: High response latency on basic math
        let summaries = sessions.compactMap(\.signalSummary)
        if !summaries.isEmpty {
            let avgLatency = summaries.map(\.averageResponseLatency).reduce(0, +) / Double(summaries.count)
            if avgLatency > 10 {
                let score: Float = min(1.0, Float(avgLatency / 20.0))
                indicators.append(IndicatorDetail(
                    name: "Slow Number Processing",
                    description: "Taking significantly longer than expected to process number-related questions",
                    score: score,
                    dataPoints: summaries.count
                ))
                totalScore += score
            }
        }

        // Indicator 3: High anxiety specifically during math
        if !summaries.isEmpty {
            let avgAnxiety = summaries.map(\.averageAnxiety).reduce(0, +) / Float(summaries.count)
            if avgAnxiety > 0.5 {
                indicators.append(IndicatorDetail(
                    name: "Math Anxiety",
                    description: "Showing elevated anxiety indicators specifically during math tasks",
                    score: avgAnxiety,
                    dataPoints: summaries.count
                ))
                totalScore += avgAnxiety
            }
        }

        let normalizedScore = indicators.isEmpty ? 0 : totalScore / Float(indicators.count)
        let confidence = Float(min(sessions.count, 30)) / 30.0

        return ScreeningResult(
            condition: .dyscalculia,
            indicatorScore: normalizedScore,
            confidence: confidence,
            indicators: indicators,
            sessionCount: sessions.count
        )
    }

    // MARK: - ADHD Screening

    private func screenForADHD(sessions: [SessionRecord]) -> ScreeningResult {
        var indicators: [IndicatorDetail] = []
        var totalScore: Float = 0

        let summaries = sessions.compactMap(\.signalSummary)

        // Indicator 1: Inconsistent response times (high variance)
        if summaries.count > 5 {
            let latencies = summaries.map(\.averageResponseLatency)
            let mean = latencies.reduce(0, +) / Double(latencies.count)
            let variance = latencies.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(latencies.count)
            let stdDev = sqrt(variance)
            let coeffOfVariation = mean > 0 ? stdDev / mean : 0

            if coeffOfVariation > 0.5 {
                let score = min(1.0, Float(coeffOfVariation))
                indicators.append(IndicatorDetail(
                    name: "Inconsistent Response Times",
                    description: "Highly variable response times across sessions, suggesting fluctuating attention",
                    score: score,
                    dataPoints: summaries.count
                ))
                totalScore += score
            }
        }

        // Indicator 2: Frequent answer changes
        if !summaries.isEmpty {
            let avgChanges = Float(summaries.map(\.totalAnswerChanges).reduce(0, +)) / Float(summaries.count)
            if avgChanges > 3 {
                let score = min(1.0, avgChanges / 8.0)
                indicators.append(IndicatorDetail(
                    name: "Frequent Answer Changes",
                    description: "Changing selected answers more often than typical, suggesting impulsivity or inattention",
                    score: score,
                    dataPoints: summaries.count
                ))
                totalScore += score
            }
        }

        // Indicator 3: Performance inconsistency across sessions
        let accuracies = sessions.map(\.accuracy)
        if accuracies.count > 5 {
            let mean = accuracies.reduce(0, +) / Double(accuracies.count)
            let variance = accuracies.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(accuracies.count)
            if variance > 0.04 {
                let score = min(1.0, Float(sqrt(variance) * 3))
                indicators.append(IndicatorDetail(
                    name: "Performance Inconsistency",
                    description: "Significant variation in performance between sessions (good days vs bad days)",
                    score: score,
                    dataPoints: accuracies.count
                ))
                totalScore += score
            }
        }

        let normalizedScore = indicators.isEmpty ? 0 : totalScore / Float(indicators.count)
        let confidence = Float(min(sessions.count, 30)) / 30.0

        return ScreeningResult(
            condition: .adhd,
            indicatorScore: normalizedScore,
            confidence: confidence,
            indicators: indicators,
            sessionCount: sessions.count
        )
    }

    // MARK: - Cognitive Decline Screening

    private func screenForCognitiveDecline(sessions: [SessionRecord]) -> ScreeningResult {
        var indicators: [IndicatorDetail] = []
        var totalScore: Float = 0

        // Indicator 1: Increasing response latency over time
        let summaries = sessions.compactMap(\.signalSummary)
        if summaries.count > 5 {
            let firstHalf = summaries.prefix(summaries.count / 2)
            let secondHalf = summaries.suffix(summaries.count / 2)

            let earlyLatency = firstHalf.map(\.averageResponseLatency).reduce(0, +) / Double(firstHalf.count)
            let lateLatency = secondHalf.map(\.averageResponseLatency).reduce(0, +) / Double(secondHalf.count)

            if lateLatency > earlyLatency * 1.2 {
                let increase = Float((lateLatency - earlyLatency) / earlyLatency)
                let score = min(1.0, increase)
                indicators.append(IndicatorDetail(
                    name: "Increasing Response Time",
                    description: "Response times have been gradually increasing over recent sessions",
                    score: score,
                    dataPoints: summaries.count
                ))
                totalScore += score
            }
        }

        // Indicator 2: Declining accuracy on previously mastered skills
        if sessions.count > 10 {
            let firstHalf = sessions.prefix(sessions.count / 2)
            let secondHalf = sessions.suffix(sessions.count / 2)

            let earlyAccuracy = firstHalf.map(\.accuracy).reduce(0, +) / Double(firstHalf.count)
            let lateAccuracy = secondHalf.map(\.accuracy).reduce(0, +) / Double(secondHalf.count)

            if lateAccuracy < earlyAccuracy - 0.1 {
                let decline = Float(earlyAccuracy - lateAccuracy)
                indicators.append(IndicatorDetail(
                    name: "Declining Accuracy",
                    description: "Performance on familiar tasks has decreased compared to earlier sessions",
                    score: min(1.0, decline * 3),
                    dataPoints: sessions.count
                ))
                totalScore += min(1.0, decline * 3)
            }
        }

        let normalizedScore = indicators.isEmpty ? 0 : totalScore / Float(indicators.count)
        let confidence = Float(min(sessions.count, 30)) / 30.0

        return ScreeningResult(
            condition: .cognitiveDecline,
            indicatorScore: normalizedScore,
            confidence: confidence,
            indicators: indicators,
            sessionCount: sessions.count
        )
    }
}
