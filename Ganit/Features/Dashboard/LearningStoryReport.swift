import Foundation
import SwiftUI

// MARK: - Learning Story Generator

/// Generates narrative weekly reports from session data using Gemini AI.
/// Pre-seeded demo data available for 3M presentation.
@MainActor
class LearningStoryGenerator: ObservableObject {

    @Published var story: LearningStory?
    @Published var isGenerating = false

    private let storage: EncryptedStorage
    private let questionService: AIQuestionService?

    init(storage: EncryptedStorage = .shared, questionService: AIQuestionService? = nil) {
        self.storage = storage
        self.questionService = questionService
    }

    // MARK: - Generate Story

    func generateStory(for username: String, sessions: [SessionRecord]) async {
        isGenerating = true

        // Analyze session data
        let analysis = analyzeSessions(sessions)

        // Try AI-generated narrative
        if let aiStory = await generateAIStory(username: username, analysis: analysis) {
            story = aiStory
        } else {
            // Fallback to template-based narrative
            story = generateTemplateStory(username: username, analysis: analysis)
        }

        isGenerating = false
    }

    // MARK: - Session Analysis

    private func analyzeSessions(_ sessions: [SessionRecord]) -> SessionAnalysis {
        let thisWeek = sessions.filter {
            $0.startedAt > Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }

        let totalQuestions = thisWeek.flatMap(\.questionResults).count
        let correctAnswers = thisWeek.flatMap(\.questionResults).filter(\.isCorrect).count
        let accuracy = totalQuestions > 0 ? Double(correctAnswers) / Double(totalQuestions) : 0

        // Find strongest and weakest topics
        var topicPerformance: [QuizMode: Double] = [:]
        for session in thisWeek {
            if let mode = session.quizMode {
                topicPerformance[mode] = session.accuracy
            }
        }
        let strongest = topicPerformance.max(by: { $0.value < $1.value })
        let weakest = topicPerformance.min(by: { $0.value < $1.value })

        // Engagement trend
        let summaries = thisWeek.compactMap(\.signalSummary)
        let avgEngagement = summaries.isEmpty ? 0.5 :
            Double(summaries.map(\.averageEngagement).reduce(0, +)) / Double(summaries.count)

        // Improvement check
        let firstHalf = thisWeek.prefix(thisWeek.count / 2)
        let secondHalf = thisWeek.suffix(thisWeek.count / 2)
        let earlyAccuracy = firstHalf.isEmpty ? 0.5 : firstHalf.map(\.accuracy).reduce(0, +) / Double(firstHalf.count)
        let lateAccuracy = secondHalf.isEmpty ? 0.5 : secondHalf.map(\.accuracy).reduce(0, +) / Double(secondHalf.count)
        let improved = lateAccuracy > earlyAccuracy + 0.05

        return SessionAnalysis(
            sessionCount: thisWeek.count,
            totalQuestions: totalQuestions,
            accuracy: accuracy,
            strongestTopic: strongest?.key,
            weakestTopic: weakest?.key,
            averageEngagement: avgEngagement,
            improved: improved,
            usedAR: thisWeek.contains { $0.signalSummary?.signalQuality == .good }
        )
    }

    // MARK: - AI Story Generation

    private func generateAIStory(username: String, analysis: SessionAnalysis) async -> LearningStory? {
        // Would use Gemini API to generate narrative — simplified for demo
        // In production, this would call questionService's model with a story prompt
        return nil
    }

    // MARK: - Template Story

    private func generateTemplateStory(username: String, analysis: SessionAnalysis) -> LearningStory {
        var paragraphs: [String] = []

        // Opening
        paragraphs.append("\(username) had a busy week of learning! They completed \(analysis.sessionCount) learning sessions and tackled \(analysis.totalQuestions) questions.")

        // Performance
        let accuracyPct = Int(analysis.accuracy * 100)
        if analysis.accuracy >= 0.8 {
            paragraphs.append("With an impressive \(accuracyPct)% accuracy, they're really mastering the material. Keep up the fantastic work!")
        } else if analysis.accuracy >= 0.6 {
            paragraphs.append("They achieved \(accuracyPct)% accuracy this week — solid progress! Every question is a chance to learn something new.")
        } else {
            paragraphs.append("This week was a learning journey with \(accuracyPct)% accuracy. Remember, making mistakes is how we grow! The important thing is they kept trying.")
        }

        // Topics
        if let strong = analysis.strongestTopic {
            paragraphs.append("\(strong.displayName) was their strongest area this week — they really showed confidence here!")
        }
        if let weak = analysis.weakestTopic, weak != analysis.strongestTopic {
            paragraphs.append("\(weak.displayName) was a bit more challenging, but that's where the most learning happens. We're adjusting the difficulty to help them build confidence.")
        }

        // Engagement
        if analysis.averageEngagement > 0.7 {
            paragraphs.append("Their engagement levels were high throughout the week — they were really focused and enjoying the learning!")
        } else if analysis.averageEngagement < 0.4 {
            paragraphs.append("We noticed some moments where engagement dipped. The AR mode might help make things more exciting — try it out next week!")
        }

        // Improvement
        if analysis.improved {
            paragraphs.append("Best of all, they showed clear improvement from the start to the end of the week. The practice is paying off!")
        }

        // AR
        if analysis.usedAR {
            paragraphs.append("They also explored math in AR this week, interacting with 3D number blocks and visualizing math concepts in a whole new way!")
        }

        // Closing
        paragraphs.append("Looking forward to another great week of learning!")

        return LearningStory(
            username: username,
            generatedAt: Date(),
            weekOf: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            narrative: paragraphs.joined(separator: "\n\n"),
            highlights: generateHighlights(analysis),
            accuracy: analysis.accuracy,
            sessionCount: analysis.sessionCount,
            totalQuestions: analysis.totalQuestions
        )
    }

    private func generateHighlights(_ analysis: SessionAnalysis) -> [String] {
        var highlights: [String] = []
        if analysis.accuracy >= 0.8 { highlights.append("Star performer: \(Int(analysis.accuracy * 100))% accuracy!") }
        if analysis.improved { highlights.append("Showed improvement throughout the week") }
        if let strong = analysis.strongestTopic { highlights.append("Excelled at \(strong.displayName)") }
        if analysis.sessionCount >= 5 { highlights.append("Completed \(analysis.sessionCount) sessions — great consistency!") }
        if analysis.usedAR { highlights.append("Explored math in AR mode") }
        return highlights
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
                "Showed clear improvement Monday → Friday",
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
    @StateObject private var generator = LearningStoryGenerator()
    let username: String
    let sessions: [SessionRecord]
    @State private var showDemo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Weekly Learning Story")
                    .font(.title2.bold())

                LearningInsightsDisclaimerView(compact: true)

                if generator.isGenerating {
                    ProgressView("Crafting your learning story...")
                        .padding()
                } else if let story = showDemo ? LearningStoryGenerator.preseededDemoStory() : generator.story {
                    storyContent(story)
                } else {
                    VStack(spacing: 12) {
                        Text("No story generated yet.")
                            .foregroundColor(.secondary)

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
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Learning Story")
    }

    @ViewBuilder
    private func storyContent(_ story: LearningStory) -> some View {
        // Stats header
        HStack(spacing: 20) {
            statBadge("\(story.sessionCount)", label: "Sessions")
            statBadge("\(story.totalQuestions)", label: "Questions")
            statBadge("\(Int(story.accuracy * 100))%", label: "Accuracy")
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)

        // Highlights
        if !story.highlights.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Highlights")
                    .font(.headline)
                ForEach(story.highlights, id: \.self) { highlight in
                    HStack(alignment: .top, spacing: 6) {
                        Text("*")
                            .foregroundColor(.yellow)
                        Text(highlight)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(12)
        }

        // Narrative
        Text(story.narrative)
            .font(.body)
            .lineSpacing(6)
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)

        // Date
        Text("Week of \(story.weekOf, style: .date)")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    private func statBadge(_ value: String, label: String) -> some View {
        VStack {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
