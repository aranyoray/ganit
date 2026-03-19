import Foundation

// MARK: - Curriculum Adapter Protocol

/// Adapts curriculum based on engagement signals. Different adapters handle
/// different user groups and conditions (dyscalculia, elderly cognitive, etc.)
protocol CurriculumAdapterProtocol {
    /// Given current state and a signal snapshot, return an updated curriculum state.
    func adapt(
        current: CurriculumState,
        signal: SignalSnapshot,
        sessionHistory: [SessionRecord]
    ) -> CurriculumState
}

// MARK: - Question Service Protocol

/// Abstracts question generation. Injectable for testing with mock responses.
protocol QuestionServiceProtocol {
    func generateMCQ(grade: Int, topic: String) async -> MCQQuestion?
    func fallbackQuestion(topic: String) -> MCQQuestion
    func recordAnswer(correct: Bool, questionText: String)
    var accuracy: Double { get }
}

// MARK: - MCQ Question

struct MCQQuestion: Codable, Equatable, Sendable {
    let question: String
    let options: [String]
    let correct_index: Int
    let hint: String

    nonisolated init(question: String, options: [String], correct_index: Int, hint: String) {
        self.question = question
        self.options = options
        self.correct_index = correct_index
        self.hint = hint
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.question = try container.decode(String.self, forKey: .question)
        self.options = try container.decode([String].self, forKey: .options)
        self.correct_index = try container.decode(Int.self, forKey: .correct_index)
        self.hint = try container.decode(String.self, forKey: .hint)
    }
}
