import XCTest
@testable import Ganit

final class RiskEngineTests: XCTestCase {

    func testInsufficientDataReturnEmptyResults() {
        let engine = RiskEngine()
        let sessions = (0..<5).map { _ in
            SessionRecord(userId: UUID(), userGroup: .child, quizMode: .addition)
        }

        let results = engine.evaluate(sessions: sessions, userGroup: .child)

        for result in results {
            XCTAssertEqual(result.indicatorScore, 0, "Should return 0 score with insufficient data")
            XCTAssertFalse(result.isSufficientData, "Should not have sufficient data with <10 sessions")
        }
    }

    func testDyscalculiaScreeningWithLowAccuracy() {
        let engine = RiskEngine()

        // Create 15 sessions with low accuracy
        var sessions: [SessionRecord] = []
        for i in 0..<15 {
            var session = SessionRecord(userId: UUID(), userGroup: .child, quizMode: .addition)
            session.endedAt = Date()
            // Add question results with ~30% accuracy
            for j in 0..<10 {
                session.questionResults.append(QuestionResult(
                    questionText: "Q\(j)",
                    selectedIndex: j < 3 ? 0 : 1,  // 3 correct, 7 wrong
                    correctIndex: 0,
                    responseLatency: 12.0  // Slow
                ))
            }
            session.signalSummary = SessionSignalSummary(
                averageEngagement: 0.4,
                averageConfusion: 0.5,
                averageFrustration: 0.3,
                averageAnxiety: 0.6,
                averageResponseLatency: 12.0,
                totalHesitations: 5,
                totalAnswerChanges: 3,
                signalQuality: .good
            )
            sessions.append(session)
        }

        let results = engine.evaluate(sessions: sessions, userGroup: .child)
        let dyscalculiaResult = results.first { $0.condition == .dyscalculia }

        XCTAssertNotNil(dyscalculiaResult)
        XCTAssertGreaterThan(dyscalculiaResult?.indicatorScore ?? 0, 0, "Should detect dyscalculia indicators")
        XCTAssertTrue(dyscalculiaResult?.isSufficientData ?? false, "Should have sufficient data")
    }

    func testCognitiveDeclineWithDecliningPerformance() {
        let engine = RiskEngine()

        var sessions: [SessionRecord] = []
        for i in 0..<20 {
            var session = SessionRecord(userId: UUID(), userGroup: .elderly, quizMode: .addition)
            session.endedAt = Date()

            // Early sessions: good accuracy. Later: declining
            let correctCount = i < 10 ? 8 : 4
            for j in 0..<10 {
                session.questionResults.append(QuestionResult(
                    questionText: "Q\(j)",
                    selectedIndex: j < correctCount ? 0 : 1,
                    correctIndex: 0,
                    responseLatency: Double(5 + i)  // Increasing latency
                ))
            }

            session.signalSummary = SessionSignalSummary(
                averageResponseLatency: Double(5 + i),
                signalQuality: .good
            )
            sessions.append(session)
        }

        let results = engine.evaluate(sessions: sessions, userGroup: .elderly)
        let declineResult = results.first { $0.condition == .cognitiveDecline }

        XCTAssertNotNil(declineResult)
        XCTAssertGreaterThan(declineResult?.indicatorScore ?? 0, 0, "Should detect cognitive decline indicators")
    }

    func testNoFalsePositiveWithGoodPerformance() {
        let engine = RiskEngine()

        var sessions: [SessionRecord] = []
        for _ in 0..<15 {
            var session = SessionRecord(userId: UUID(), userGroup: .child, quizMode: .addition)
            session.endedAt = Date()
            for j in 0..<10 {
                session.questionResults.append(QuestionResult(
                    questionText: "Q\(j)",
                    selectedIndex: 0,
                    correctIndex: 0,
                    responseLatency: 3.0
                ))
            }
            session.signalSummary = SessionSignalSummary(
                averageEngagement: 0.8,
                averageResponseLatency: 3.0,
                signalQuality: .good
            )
            sessions.append(session)
        }

        let results = engine.evaluate(sessions: sessions, userGroup: .child)

        for result in results {
            XCTAssertFalse(result.shouldRecommendProfessional, "Should not recommend professional for good performance")
        }
    }
}
