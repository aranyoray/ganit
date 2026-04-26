import Foundation

// MARK: - Screening Condition

enum ScreeningCondition: String, Codable, CaseIterable {
    case dyscalculia
    case adhd
    case cognitiveDecline
}

// MARK: - Screening Result

struct ScreeningResult: Codable, Identifiable {
    let id: UUID
    let condition: ScreeningCondition
    let indicatorScore: Float        // 0-1, higher = more indicators present
    let confidence: Float            // how many data points informed this
    let indicators: [IndicatorDetail]
    let sessionCount: Int
    let evaluatedAt: Date

    init(
        condition: ScreeningCondition,
        indicatorScore: Float,
        confidence: Float,
        indicators: [IndicatorDetail],
        sessionCount: Int
    ) {
        self.id = UUID()
        self.condition = condition
        self.indicatorScore = indicatorScore
        self.confidence = confidence
        self.indicators = indicators
        self.sessionCount = sessionCount
        self.evaluatedAt = Date()
    }

    /// Whether this result has enough data to be meaningful.
    var isSufficientData: Bool { sessionCount >= 10 }

    /// Whether indicators are above threshold for recommendation.
    var shouldRecommendProfessional: Bool {
        isSufficientData && indicatorScore >= 0.6 && confidence >= 0.5
    }
}

// MARK: - Indicator Detail

struct IndicatorDetail: Codable {
    let name: String
    let description: String
    let score: Float       // 0-1
    let dataPoints: Int    // how many observations informed this
}

// MARK: - Assessment Report

struct AssessmentReport: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let generatedAt: Date
    let screeningResults: [ScreeningResult]
    let sessionsSinceLastReport: Int
    let totalSessions: Int

    /// User-friendly summary text.
    var summaryText: String {
        let flagged = screeningResults.filter(\.shouldRecommendProfessional)
        guard !flagged.isEmpty else {
            if totalSessions < 10 {
                return "We need more learning sessions to provide meaningful insights. Keep practicing!"
            }
            return "No concerning patterns detected. Keep up the great work!"
        }

        let conditions = flagged.map(\.condition.displayName).joined(separator: " and ")
        return "We've noticed some patterns related to \(conditions) that may be worth exploring with an education professional. These are educational observations, not medical diagnoses — just something to explore further."
    }
}

// MARK: - Display Helpers

extension ScreeningCondition {
    var displayName: String {
        switch self {
        case .dyscalculia:     return "math confidence indicators"
        case .adhd:            return "attention pattern insights"
        case .cognitiveDecline: return "cognitive wellness trends"
        }
    }
}

// MARK: - Educational Disclaimer

enum LearningInsightsDisclaimer {
    static let text = "These learning insights are educational observations based on interaction patterns. They are not medical diagnoses, screenings, or assessments. If you have concerns about your child's learning, please consult a qualified education or healthcare professional."
    static let short = "Educational observations only — not medical advice."
}
