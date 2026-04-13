import Foundation

// MARK: - Session Record

/// Captures a complete learning session: questions, answers, signals, and outcomes.
struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let startedAt: Date
    var endedAt: Date?
    var quizMode: QuizMode?
    var userGroup: UserGroup

    // Questions and answers
    var questionResults: [QuestionResult] = []

    // Aggregated signal data (stored at session end, not per-snapshot)
    var signalSummary: SessionSignalSummary?

    // Curriculum state before and after
    var difficultyAtStart: String = "medium"
    var difficultyAtEnd: String = "medium"
    var levelAtStart: Int = 0
    var levelAtEnd: Int = 0

    init(userId: UUID, userGroup: UserGroup, quizMode: QuizMode? = nil) {
        self.id = UUID()
        self.userId = userId
        self.startedAt = Date()
        self.userGroup = userGroup
        self.quizMode = quizMode
    }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    var accuracy: Double {
        let total = questionResults.count
        guard total > 0 else { return 0.5 }
        let correct = questionResults.filter(\.isCorrect).count
        return Double(correct) / Double(total)
    }

    var questionCount: Int { questionResults.count }
}

// MARK: - Question Result

struct QuestionResult: Codable, Identifiable {
    let id: UUID
    let questionText: String
    let selectedIndex: Int
    let correctIndex: Int
    let responseLatency: TimeInterval
    let answerChanges: Int
    let timestamp: Date

    var isCorrect: Bool { selectedIndex == correctIndex }

    init(
        questionText: String,
        selectedIndex: Int,
        correctIndex: Int,
        responseLatency: TimeInterval,
        answerChanges: Int = 0
    ) {
        self.id = UUID()
        self.questionText = questionText
        self.selectedIndex = selectedIndex
        self.correctIndex = correctIndex
        self.responseLatency = responseLatency
        self.answerChanges = answerChanges
        self.timestamp = Date()
    }
}

// MARK: - Session Signal Summary

/// Aggregated signal data for an entire session. Stored once at session end.
struct SessionSignalSummary: Codable {
    var averageEngagement: Float = 0
    var averageConfusion: Float = 0
    var averageFrustration: Float = 0
    var averageAnxiety: Float = 0
    var averageResponseLatency: TimeInterval = 0
    var totalHesitations: Int = 0
    var totalAnswerChanges: Int = 0
    var gazeAvoidanceRatio: Float = 0   // fraction of time gaze was away
    var averageSaccadeRate: Float = 0   // saccades per question
    var dominantExpression: ExpressionCategory = .neutral
    var signalQuality: SignalQuality = .noData

    /// Aggregate from per-question snapshots
    static func from(snapshots: [SignalSnapshot]) -> SessionSignalSummary {
        guard !snapshots.isEmpty else { return SessionSignalSummary() }
        let count = Float(snapshots.count)

        var summary = SessionSignalSummary()
        summary.averageEngagement = snapshots.map(\.engagementScore).reduce(0, +) / count
        summary.averageConfusion = snapshots.map(\.confusionScore).reduce(0, +) / count
        summary.averageFrustration = snapshots.map(\.frustrationScore).reduce(0, +) / count
        summary.averageAnxiety = snapshots.map(\.anxietyScore).reduce(0, +) / count
        summary.averageResponseLatency = snapshots.map(\.responseLatency).reduce(0, +) / Double(count)
        summary.totalHesitations = snapshots.map(\.hesitationCount).reduce(0, +)
        summary.totalAnswerChanges = snapshots.map(\.answerChanges).reduce(0, +)
        summary.averageSaccadeRate = Float(snapshots.map(\.saccadeCount).reduce(0, +)) / count
        summary.signalQuality = .good

        // Dominant expression: most frequent
        let expressionCounts = Dictionary(grouping: snapshots, by: \.dominantExpression)
            .mapValues(\.count)
        summary.dominantExpression = expressionCounts.max(by: { $0.value < $1.value })?.key ?? .neutral

        return summary
    }
}
