import Foundation

// MARK: - Signal Snapshot

/// A single point-in-time capture of all multimodal signals during a question.
struct SignalSnapshot: Codable {
    let timestamp: Date
    let questionId: String

    // Eye tracking
    var gazeFixations: [GazeFixation] = []
    var saccadeCount: Int = 0
    var gazeAvoidanceDuration: TimeInterval = 0

    // Facial expression
    var dominantExpression: ExpressionCategory = .neutral
    var expressionConfidence: Float = 0
    var expressionTimeline: [ExpressionSample] = []

    // Touch patterns
    var responseLatency: TimeInterval = 0
    var hesitationCount: Int = 0
    var answerChanges: Int = 0
    var touchPressure: Float?

    // Voice signals (V3)
    var speechRate: Double = 0
    var voiceHesitationCount: Int = 0
    var voiceConfidence: Float = 0.5
    var voiceActive: Bool = false

    // Derived engagement scores (0-1)
    var engagementScore: Float = 0.5
    var confusionScore: Float = 0
    var frustrationScore: Float = 0
    var anxietyScore: Float = 0
}

// MARK: - Supporting Types

struct GazeFixation: Codable {
    let region: GazeRegion
    let duration: TimeInterval
    let timestamp: Date
}

enum GazeRegion: String, Codable {
    case questionText
    case optionA, optionB, optionC, optionD
    case elsewhere
    case unknown
}

enum ExpressionCategory: String, Codable {
    case engaged
    case confused
    case frustrated
    case anxious
    case bored
    case neutral
    case ambiguous
}

struct ExpressionSample: Codable {
    let timestamp: Date
    let category: ExpressionCategory
    let confidence: Float
}

// MARK: - Signal Quality

enum SignalQuality: String, Codable {
    case good
    case lowConfidence
    case noData
}
