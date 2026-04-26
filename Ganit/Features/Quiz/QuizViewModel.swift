import Foundation
import SwiftUI
import Combine

// MARK: - Quiz View Model

/// Unified quiz logic for all operation modes. Replaces the 4 duplicate operation views.
/// Includes signal collection hooks and haptic feedback.
@MainActor
class QuizViewModel: ObservableObject {

    // MARK: - Published State

    @Published var currentQuestion: MCQQuestion?
    @Published var selectedIndex: Int?
    @Published var answered = false
    @Published var showHint = false
    @Published var streak: Int = 0
    @Published var resultMessage: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var useFallback = false

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

    // MARK: - Question Loading

    func loadQuestion() async {
        isLoading = true
        errorMessage = nil
        questionStartTime = Date()
        currentAnswerChanges = 0

        if useFallback {
            currentQuestion = questionService.fallbackQuestion(topic: mode.topic)
            isLoading = false
            touchProvider.questionDidAppear()
            return
        }

        await questionService.loadNextQuestion(grade: grade, topic: mode.topic)
        currentQuestion = questionService.currentQuestion
        errorMessage = questionService.errorMessage
        isLoading = false

        if currentQuestion != nil {
            touchProvider.questionDidAppear()
            // Prefetch next questions
            if questionService.questionQueue.count < 2 {
                Task { await questionService.prefetchQuestions(grade: grade, topic: mode.topic, count: 2) }
            }
        }
    }

    func switchToOffline() {
        useFallback = true
        currentQuestion = questionService.fallbackQuestion(topic: mode.topic)
        errorMessage = nil
        touchProvider.questionDidAppear()
    }

    // MARK: - Answer Handling

    func selectAnswer(index: Int) {
        guard !answered else { return }

        // Track answer changes for signal collection
        if selectedIndex != nil && selectedIndex != index {
            currentAnswerChanges += 1
            touchProvider.optionDeselected(index: selectedIndex!)
        }

        selectedIndex = index
        answered = true
        touchProvider.optionSelected(index: index)
        touchProvider.answerSubmitted()

        guard let question = currentQuestion else { return }
        let isCorrect = index == question.correct_index

        // Calculate response latency
        let latency = questionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        if isCorrect {
            resultMessage = "Correct!"
            streak += 1
            let points = mode.pointMultiplier * progressState.powerUpPointLevel
            progressState.score += points
            progressState.progress += mode.xpReward
            progressState.incrementLevel(for: mode)
            if progressState.progress >= CGFloat(progressState.xpRequirements) {
                progressState.advanceLevel()
            }
            // Haptic success feedback
            HapticManager.success()
        } else {
            resultMessage = "Not quite — the answer is \(question.options[question.correct_index])"
            streak = 0
            progressState.score = max(0, progressState.score - 1)
            progressState.progress = max(0, progressState.progress - 10)
            showHint = true
            // Haptic error feedback
            HapticManager.error()
        }

        questionService.recordAnswer(correct: isCorrect, questionText: question.question)

        // Capture signal snapshot for this question
        let snapshot = SignalSnapshot(
            timestamp: Date(),
            questionId: question.question,
            responseLatency: latency,
            hesitationCount: touchProvider.currentHesitationCount,
            answerChanges: currentAnswerChanges
        )
        sessionSnapshots.append(snapshot)
    }

    // MARK: - Next Question

    func nextQuestion() {
        selectedIndex = nil
        answered = false
        showHint = false
        resultMessage = ""
        questionStartTime = Date()
        currentAnswerChanges = 0

        if useFallback {
            currentQuestion = questionService.fallbackQuestion(topic: mode.topic)
            touchProvider.questionDidAppear()
        } else {
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

/// Proximity-based haptic hints and answer feedback.
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

    /// Warmer/colder haptic: intensity increases as finger approaches correct option.
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
