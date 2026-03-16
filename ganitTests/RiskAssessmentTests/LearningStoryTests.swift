import XCTest
@testable import Ganit

final class LearningStoryTests: XCTestCase {

    func testPreseededDemoStoryIsValid() {
        let story = LearningStoryGenerator.preseededDemoStory()

        XCTAssertEqual(story.username, "Sara")
        XCTAssertFalse(story.narrative.isEmpty)
        XCTAssertGreaterThan(story.highlights.count, 0)
        XCTAssertEqual(story.accuracy, 0.82, accuracy: 0.01)
        XCTAssertEqual(story.sessionCount, 8)
        XCTAssertEqual(story.totalQuestions, 64)
    }

    func testScreeningResultDisclaimerLanguage() {
        // Verify we never use diagnostic language
        let result = ScreeningResult(
            condition: .dyscalculia,
            indicatorScore: 0.8,
            confidence: 0.7,
            indicators: [
                IndicatorDetail(name: "test", description: "test desc", score: 0.8, dataPoints: 15)
            ],
            sessionCount: 15
        )

        let report = AssessmentReport(
            id: UUID(),
            userId: UUID(),
            generatedAt: Date(),
            screeningResults: [result],
            sessionsSinceLastReport: 5,
            totalSessions: 15
        )

        // Should use "patterns" and "specialist" not "diagnosis" or "disorder"
        XCTAssertTrue(report.summaryText.contains("patterns"))
        XCTAssertTrue(report.summaryText.contains("specialist"))
        XCTAssertFalse(report.summaryText.lowercased().contains("diagnos"))
    }

    func testAssessmentReportWithInsufficientData() {
        let report = AssessmentReport(
            id: UUID(),
            userId: UUID(),
            generatedAt: Date(),
            screeningResults: [],
            sessionsSinceLastReport: 3,
            totalSessions: 5
        )

        XCTAssertTrue(report.summaryText.contains("more learning sessions"))
    }

    func testAssessmentReportAllClear() {
        let result = ScreeningResult(
            condition: .dyscalculia,
            indicatorScore: 0.2,  // Low — no concern
            confidence: 0.8,
            indicators: [],
            sessionCount: 15
        )

        let report = AssessmentReport(
            id: UUID(),
            userId: UUID(),
            generatedAt: Date(),
            screeningResults: [result],
            sessionsSinceLastReport: 5,
            totalSessions: 15
        )

        XCTAssertTrue(report.summaryText.contains("No concerning patterns"))
    }
}
