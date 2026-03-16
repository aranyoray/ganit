import Foundation
import Combine
import SwiftUI

// MARK: - Learning Story Generator

@MainActor
class LearningStoryGenerator: ObservableObject {

    @Published var story: LearningStory?
    @Published var isGenerating = false

    private let storage: EncryptedStorage
    private let questionService: AIQuestionService?

    init(storage: EncryptedStorage, questionService: AIQuestionService? = nil) {
        self.storage = storage
        self.questionService = questionService
    }

    func generateStory(for username: String, sessions: [SessionRecord]) async {
        isGenerating = true

        let thisWeek = sessions.filter {
            $0.startedAt > Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }
        let totalQuestions = thisWeek.flatMap(\.questionResults).count
        let correctAnswers = thisWeek.flatMap(\.questionResults).filter(\.isCorrect).count
        let accuracy = totalQuestions > 0 ? Double(correctAnswers) / Double(totalQuestions) : 0

        story = LearningStory(
            username: username,
            generatedAt: Date(),
            weekOf: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            narrative: "This week: \(thisWeek.count) sessions, \(Int(accuracy * 100))% accuracy, \(totalQuestions) questions answered.",
            highlights: [],
            accuracy: accuracy,
            sessionCount: thisWeek.count,
            totalQuestions: totalQuestions
        )

        isGenerating = false
    }

    // MARK: - Demo Data

    static func preseededDemoStory() -> LearningStory {
        LearningStory(
            username: "Sara",
            generatedAt: Date(),
            weekOf: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            narrative: """
            Sara had an amazing week of learning! She completed 8 learning sessions and tackled 64 questions.

            She started the week working on fractions, which she found a bit tricky — her accuracy was around 55% on Monday. But by Wednesday, something clicked! She was slicing pizzas in AR like a pro, achieving 78% accuracy.

            Addition continues to be her strongest area — she zoomed through those problems with 92% accuracy and a smile on her face. We noticed her engagement peaked during the AR Number Playground, where she spent extra time stacking and grouping blocks on her own.

            Thursday was her best day: she got 9 out of 10 questions right on multiplication, and our sensors showed she was fully engaged and confident the whole time.

            We did notice some anxiety patterns specifically around division problems. The app automatically switched to softer colors and removed the timer when it detected this. By Friday, her division accuracy improved to 70%!

            Looking forward to another great week of learning!
            """,
            highlights: [
                "Star performer: 82% average accuracy!",
                "Mastered fractions through AR pizza slicing",
                "Addition champion: 92% accuracy",
                "Showed clear improvement Monday -> Friday",
                "Explored math in AR Number Playground"
            ],
            accuracy: 0.82,
            sessionCount: 8,
            totalQuestions: 64
        )
    }
}

// MARK: - Models

struct LearningStory: Codable, Identifiable {
    let id: UUID
    let username: String
    let generatedAt: Date
    let weekOf: Date
    let narrative: String
    let highlights: [String]
    let accuracy: Double
    let sessionCount: Int
    let totalQuestions: Int

    init(username: String, generatedAt: Date, weekOf: Date, narrative: String, highlights: [String], accuracy: Double, sessionCount: Int, totalQuestions: Int) {
        self.id = UUID()
        self.username = username
        self.generatedAt = generatedAt
        self.weekOf = weekOf
        self.narrative = narrative
        self.highlights = highlights
        self.accuracy = accuracy
        self.sessionCount = sessionCount
        self.totalQuestions = totalQuestions
    }
}

struct SessionAnalysis {
    let sessionCount: Int
    let totalQuestions: Int
    let accuracy: Double
    let strongestTopic: QuizMode?
    let weakestTopic: QuizMode?
    let averageEngagement: Double
    let improved: Bool
    let usedAR: Bool
}

// MARK: - Learning Story View

struct LearningStoryView: View {
    @StateObject private var generator = LearningStoryGenerator(storage: EncryptedStorage.shared)
    let username: String
    let sessions: [SessionRecord]
    @State private var showDemo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Weekly Learning Story")
                    .font(.title2.bold())

                if generator.isGenerating {
                    ProgressView("Generating...")
                } else if let story = showDemo ? LearningStoryGenerator.preseededDemoStory() : generator.story {
                    // Stats
                    HStack {
                        Text("\(story.sessionCount) sessions")
                        Spacer()
                        Text("\(story.totalQuestions) questions")
                        Spacer()
                        Text("\(Int(story.accuracy * 100))%")
                    }
                    .font(.headline)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                    // Narrative
                    Text(story.narrative)
                        .font(.body)
                        .padding()

                    Text("Week of \(story.weekOf, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button("Generate This Week's Story") {
                        Task {
                            await generator.generateStory(for: username, sessions: sessions)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Show Demo Story") {
                        showDemo = true
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Learning Story")
    }
}
