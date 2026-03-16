import Foundation
import Combine
#if canImport(GoogleGenerativeAI)
import GoogleGenerativeAI
#endif

// MARK: - AI Question Service

/// Extracted from ganit_base/AIService.swift. Protocol-based, injectable.
/// Handles Gemini API question generation with offline fallback and prefetch queue.
/// When GoogleGenerativeAI SPM package is not available, uses offline fallback only.
@MainActor
class AIQuestionService: ObservableObject, QuestionServiceProtocol {

    @Published var isLoading = false
    @Published var currentQuestion: MCQQuestion?
    @Published var questionQueue: [MCQQuestion] = []
    @Published var errorMessage: String?
    @Published var needsAPIKey = false

    #if canImport(GoogleGenerativeAI)
    private var model: GenerativeModel?
    #endif
    private var consecutiveFailures: Int = 0
    private var totalAttempts: Int = 0
    private var correctAttempts: Int = 0
    private var recentMistakes: [String] = []
    private let storage: EncryptedStorage

    var accuracy: Double {
        totalAttempts == 0 ? 0.5 : Double(correctAttempts) / Double(totalAttempts)
    }

    init(storage: EncryptedStorage) {
        self.storage = storage
        #if canImport(GoogleGenerativeAI)
        if let key = storage.loadAPIKey() {
            model = GenerativeModel(name: "gemini-2.5-flash", apiKey: key)
        } else {
            needsAPIKey = true
        }
        #else
        needsAPIKey = false  // Offline mode only
        #endif
    }

    func configure(apiKey: String) {
        storage.saveAPIKey(apiKey)
        #if canImport(GoogleGenerativeAI)
        model = GenerativeModel(name: "gemini-2.5-flash", apiKey: apiKey)
        #endif
        needsAPIKey = false
    }

    // MARK: - QuestionServiceProtocol

    func recordAnswer(correct: Bool, questionText: String) {
        totalAttempts += 1
        if correct {
            correctAttempts += 1
        } else {
            recentMistakes.append(questionText)
            if recentMistakes.count > 5 {
                recentMistakes.removeFirst()
            }
        }
    }

    func generateMCQ(grade: Int, topic: String) async -> MCQQuestion? {
        #if canImport(GoogleGenerativeAI)
        guard let model else { return nil }

        // Circuit breaker: after 3 consecutive failures, stop trying
        guard consecutiveFailures < 3 else { return nil }

        let difficulty = DifficultyLevel.from(accuracy: accuracy).rawValue
        let mistakesText = recentMistakes.isEmpty ? "none" : recentMistakes.suffix(3).joined(separator: "; ")

        let prompt = """
        You are a friendly math tutor designing multiple-choice math questions for children.

        Student profile:
        - Grade: \(grade)
        - Topic: \(topic)
        - Current accuracy: \(String(format: "%.0f", accuracy * 100))%
        - Difficulty level: \(difficulty)
        - Recent mistakes: \(mistakesText)

        Allowed topics by grade:
        - Grade 1-2: counting, number recognition, simple addition/subtraction (single digit)
        - Grade 2-3: addition, subtraction (two digits)
        - Grade 4-5: multiplication, division (two digits)
        - Grade 6-7: fractions, decimals, multi-step problems

        Generate ONE math multiple choice question.

        Requirements:
        - Suitable for grade \(grade) level \(topic)
        - Calm, supportive tone
        - Short question text
        - Exactly 4 options
        - Exactly one correct answer
        - A short, helpful hint

        Return ONLY valid JSON with no extra text:
        {"question": "text", "options": ["A", "B", "C", "D"], "correct_index": 0, "hint": "short hint"}
        """

        // Run API call off main actor with 3-second timeout
        let apiModel = model
        let apiTask = Task.detached { () -> MCQQuestion? in
            do {
                let response = try await apiModel.generateContent(prompt)
                guard let text = response.text else { return nil }
                let cleaned = text
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard let data = cleaned.data(using: .utf8) else { return nil }
                return try JSONDecoder().decode(MCQQuestion.self, from: data)
            } catch {
                return nil
            }
        }

        // Race against 3-second timeout
        let timeoutTask = Task.detached {
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }

        // Wait for whichever finishes first
        let result: MCQQuestion? = await withTaskGroup(of: MCQQuestion?.self) { group in
            group.addTask { await apiTask.value }
            group.addTask {
                try? await timeoutTask.value
                return nil  // timeout → nil
            }
            let first = await group.next() ?? nil
            apiTask.cancel()
            timeoutTask.cancel()
            group.cancelAll()
            return first
        }

        if let question = result {
            consecutiveFailures = 0
            return question
        } else {
            consecutiveFailures += 1
            if consecutiveFailures == 1 {
                SignalLogger.signalProviderStarted("AIQuestionService", available: false)
            }
            return nil
        }
        #else
        return nil  // Will use fallback
        #endif
    }

    /// Whether the Gemini API is available (model configured, not circuit-broken).
    var hasAPI: Bool {
        #if canImport(GoogleGenerativeAI)
        return model != nil && consecutiveFailures < 3
        #else
        return false
        #endif
    }

    func loadNextQuestion(grade: Int, topic: String) async {
        isLoading = true
        errorMessage = nil
        currentQuestion = nil

        if !questionQueue.isEmpty {
            currentQuestion = questionQueue.removeFirst()
            isLoading = false
            return
        }

        // If no API key, skip network entirely — instant fallback
        guard hasAPI else {
            currentQuestion = Self.generateFallback(topic: topic)
            isLoading = false
            return
        }

        // API available: try with timeout
        if let q = await generateMCQ(grade: grade, topic: topic) {
            currentQuestion = q
        } else {
            currentQuestion = Self.generateFallback(topic: topic)
        }
        isLoading = false
    }

    func prefetchQuestions(grade: Int, topic: String, count: Int = 3) async {
        for _ in 0..<count {
            if let q = await generateMCQ(grade: grade, topic: topic) {
                questionQueue.append(q)
            }
        }
    }

    // MARK: - Offline Fallback

    func fallbackQuestion(topic: String) -> MCQQuestion {
        Self.generateFallback(topic: topic)
    }

    static func generateFallback(topic: String) -> MCQQuestion {
        let a: Int, b: Int, correctAnswer: Int, questionText: String

        switch topic {
        case "addition":
            a = Int.random(in: 1...50)
            b = Int.random(in: 1...50)
            correctAnswer = a + b
            questionText = "What is \(a) + \(b)?"
        case "subtraction":
            a = Int.random(in: 10...100)
            b = Int.random(in: 1...a)
            correctAnswer = a - b
            questionText = "What is \(a) - \(b)?"
        case "multiplication":
            a = Int.random(in: 1...12)
            b = Int.random(in: 1...12)
            correctAnswer = a * b
            questionText = "What is \(a) × \(b)?"
        case "division":
            b = Int.random(in: 1...12)
            correctAnswer = Int.random(in: 1...12)
            a = b * correctAnswer
            questionText = "What is \(a) ÷ \(b)?"
        default:
            a = Int.random(in: 1...20)
            b = Int.random(in: 1...20)
            correctAnswer = a + b
            questionText = "What is \(a) + \(b)?"
        }

        let correctIndex = Int.random(in: 0...3)
        var usedAnswers: Set<Int> = [correctAnswer]
        var options = [String]()
        for i in 0..<4 {
            if i == correctIndex {
                options.append("\(correctAnswer)")
            } else {
                var wrong = correctAnswer
                var attempts = 0
                while usedAnswers.contains(wrong) && attempts < 20 {
                    switch topic {
                    case "multiplication":
                        let offBy = Int.random(in: 1...3)
                        wrong = Bool.random() ? a * (b + offBy) : a * (b - offBy)
                    case "division":
                        wrong = Int.random(in: max(1, correctAnswer - 3)...correctAnswer + 3)
                    default:
                        wrong = correctAnswer + Int.random(in: 1...5) * (Bool.random() ? 1 : -1)
                    }
                    if wrong < 0 { wrong = abs(wrong) + 1 }
                    attempts += 1
                }
                if usedAnswers.contains(wrong) { wrong = correctAnswer + usedAnswers.count + 1 }
                usedAnswers.insert(wrong)
                options.append("\(wrong)")
            }
        }

        return MCQQuestion(
            question: questionText,
            options: options,
            correct_index: correctIndex,
            hint: "Think step by step!"
        )
    }
}
