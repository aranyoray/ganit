import Foundation
import SwiftUI
import Combine

// MARK: - Quiz State Machine

/// Prevents impossible states: can't answer while loading, can't load while answered.
///
/// ```
/// .idle ──loadQuestion()──▶ .loading
///   ▲                          │
///   │                    success/fail
///   │                          ▼
///   │                  .presenting(question)
///   │                          │
///   │                   selectAnswer()
///   │                          ▼
///   │                  .answered(correct, question)
///   │                          │
///   │                   nextQuestion()
///   └──────────────────────────┘
///         (also → .error on failure)
/// ```
enum QuizState: Equatable {
    case idle
    case loading
    case presenting(MCQQuestion)
    case answered(correct: Bool, question: MCQQuestion)
    case sessionComplete
    case error(String)

    static func == (lhs: QuizState, rhs: QuizState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.sessionComplete, .sessionComplete): return true
        case (.presenting(let a), .presenting(let b)): return a == b
        case (.answered(let c1, let q1), .answered(let c2, let q2)): return c1 == c2 && q1 == q2
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Quiz View Model

/// Unified quiz logic for all operation modes with state machine.
@MainActor
class QuizViewModel: ObservableObject {

    // MARK: - State

    @Published var state: QuizState = .idle
    @Published var selectedIndex: Int?
    @Published var showHint = false
    @Published var streak: Int = 0
    @Published var resultMessage: String = ""
    @Published var useFallback = false

    // Session tracking
    static let questionsPerSession = 10
    @Published var questionsAnswered: Int = 0
    @Published var correctCount: Int = 0
    @Published var sessionXPEarned: CGFloat = 0
    @Published var sessionCoinsEarned: Int = 0
    @Published var bestStreak: Int = 0

    // Convenience accessors for the view
    var isLoading: Bool { state == .loading }
    var currentQuestion: MCQQuestion? {
        switch state {
        case .presenting(let q): return q
        case .answered(_, let q): return q
        default: return nil
        }
    }
    var isAnswered: Bool {
        if case .answered = state { return true }
        return false
    }
    var errorMessage: String? {
        if case .error(let msg) = state { return msg }
        return nil
    }

    // MARK: - Dependencies

    let mode: QuizMode
    private let questionService: AIQuestionService
    private let progressState: ProgressState
    private let touchProvider: TouchPatternProvider
    private var sessionSnapshots: [SignalSnapshot] = []
    private var questionStartTime: Date?
    private var currentAnswerChanges: Int = 0

    var currentLevel: Int { progressState.levelFor(mode: mode) }
    var grade: Int { gradeFromLevel(currentLevel) }
    var accuracy: Double { questionService.accuracy }

    // MARK: - Init

    init(
        mode: QuizMode,
        questionService: AIQuestionService,
        progressState: ProgressState,
        touchProvider: TouchPatternProvider
    ) {
        self.mode = mode
        self.questionService = questionService
        self.progressState = progressState
        self.touchProvider = touchProvider
    }

    // MARK: - Load Question

    func loadQuestion() async {
        guard state == .idle || state == .loading else { return }
        state = .loading
        questionStartTime = Date()
        currentAnswerChanges = 0

        // Auto-enable fallback if no API configured
        if !questionService.hasAPI {
            useFallback = true
        }

        if useFallback {
            let q = questionService.fallbackQuestion(topic: mode.topic)
            state = .presenting(q)
            touchProvider.questionDidAppear()
            return
        }

        await questionService.loadNextQuestion(grade: grade, topic: mode.topic)

        if let q = questionService.currentQuestion {
            state = .presenting(q)
            touchProvider.questionDidAppear()
            if questionService.questionQueue.count < 2 {
                Task { await questionService.prefetchQuestions(grade: grade, topic: mode.topic, count: 2) }
            }
        } else if let err = questionService.errorMessage {
            state = .error(err)
        } else {
            // Last resort: use fallback instead of showing error
            let q = questionService.fallbackQuestion(topic: mode.topic)
            state = .presenting(q)
            touchProvider.questionDidAppear()
            useFallback = true
        }
    }

    func switchToOffline() {
        useFallback = true
        let q = questionService.fallbackQuestion(topic: mode.topic)
        state = .presenting(q)
        touchProvider.questionDidAppear()
    }

    // MARK: - Select Answer

    func selectAnswer(index: Int) {
        guard case .presenting(let question) = state else { return }

        // Track answer changes
        if let prev = selectedIndex, prev != index {
            currentAnswerChanges += 1
            touchProvider.optionDeselected(index: prev)
        }

        selectedIndex = index
        touchProvider.optionSelected(index: index)
        touchProvider.answerSubmitted()

        let isCorrect = index == question.correct_index
        let latency = questionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        questionsAnswered += 1

        if isCorrect {
            resultMessage = "Correct!"
            streak += 1
            bestStreak = max(bestStreak, streak)
            correctCount += 1
            let points = mode.pointMultiplier * progressState.powerUpPointLevel
            progressState.score += points
            let xp = mode.xpReward
            progressState.progress += xp
            sessionXPEarned += xp
            progressState.incrementLevel(for: mode)
            if progressState.progress >= CGFloat(progressState.xpRequirements) {
                progressState.advanceLevel()
            }
            HapticManager.success()
        } else {
            resultMessage = "Not quite — the answer is \(question.options[question.correct_index])"
            streak = 0
            progressState.score = max(0, progressState.score - 1)
            progressState.progress = max(0, progressState.progress - 10)
            showHint = true
            HapticManager.error()
        }

        questionService.recordAnswer(correct: isCorrect, questionText: question.question)

        let snapshot = SignalSnapshot(
            timestamp: Date(),
            questionId: question.question,
            responseLatency: latency,
            hesitationCount: touchProvider.currentHesitationCount,
            answerChanges: currentAnswerChanges
        )
        sessionSnapshots.append(snapshot)

        state = .answered(correct: isCorrect, question: question)
    }

    // MARK: - Next Question

    func nextQuestion() {
        guard case .answered = state else { return }

        // Check if session is complete
        if questionsAnswered >= Self.questionsPerSession {
            // Award coins based on performance
            let accuracyPercent = Double(correctCount) / Double(questionsAnswered)
            let coinReward: Int
            if accuracyPercent >= 0.9 {
                coinReward = 25   // Excellent
            } else if accuracyPercent >= 0.7 {
                coinReward = 15   // Good
            } else if accuracyPercent >= 0.5 {
                coinReward = 8    // OK
            } else {
                coinReward = 3    // Participation
            }
            // Streak bonus
            let streakBonus = bestStreak >= 5 ? 10 : (bestStreak >= 3 ? 5 : 0)
            sessionCoinsEarned = coinReward + streakBonus
            progressState.coins += sessionCoinsEarned

            state = .sessionComplete
            return
        }

        selectedIndex = nil
        showHint = false
        resultMessage = ""
        questionStartTime = Date()
        currentAnswerChanges = 0
        state = .idle

        if useFallback {
            let q = questionService.fallbackQuestion(topic: mode.topic)
            state = .presenting(q)
            touchProvider.questionDidAppear()
        } else {
            Task { await loadQuestion() }
        }
    }

    func startNewSession() {
        questionsAnswered = 0
        correctCount = 0
        sessionXPEarned = 0
        sessionCoinsEarned = 0
        bestStreak = 0
        streak = 0
        selectedIndex = nil
        showHint = false
        resultMessage = ""
        questionStartTime = Date()
        currentAnswerChanges = 0

        if useFallback {
            let q = questionService.fallbackQuestion(topic: mode.topic)
            state = .presenting(q)
            touchProvider.questionDidAppear()
        } else {
            state = .idle
            Task { await loadQuestion() }
        }
    }

    // MARK: - Session Management

    func endSession(userId: UUID, userGroup: UserGroup) -> SessionRecord {
        var session = SessionRecord(userId: userId, userGroup: userGroup, quizMode: mode)
        session.endedAt = Date()
        session.signalSummary = SessionSignalSummary.from(snapshots: sessionSnapshots)
        sessionSnapshots.removeAll()
        return session
    }
}

// MARK: - Haptic Manager

enum HapticManager {
    static func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    static func error() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }

    static func proximityHint(distanceFromCorrect: CGFloat) {
        #if os(iOS)
        let intensity = max(0.1, min(1.0, Float(1.0 - distanceFromCorrect)))
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: CGFloat(intensity))
        #endif
    }

    static func light() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}
