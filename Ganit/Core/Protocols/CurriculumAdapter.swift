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

struct MCQQuestion: Codable, Equatable {
    let question: String
    let options: [String]
    let correct_index: Int
    let hint: String
}
