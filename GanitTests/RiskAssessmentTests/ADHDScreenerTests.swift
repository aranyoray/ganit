import XCTest
@testable import Ganit

final class ADHDScreenerTests: XCTestCase {

    func testADHDDetectedWithHighResponseVariance() {
        let engine = RiskEngine()

        var sessions: [SessionRecord] = []
        for i in 0..<15 {
            var session = SessionRecord(userId: UUID(), userGroup: .child, quizMode: .addition)
            session.endedAt = Date()

            // Highly variable response times (ADHD indicator)
            let latency = i % 2 == 0 ? 2.0 : 15.0  // Alternating fast and slow
            for j in 0..<10 {
                session.questionResults.append(QuestionResult(
                    questionText: "Q\(j)",
                    selectedIndex: Bool.random() ? 0 : 1,
                    correctIndex: 0,
                    responseLatency: latency + Double.random(in: -1...1)
                ))
            }

            session.signalSummary = SessionSignalSummary(
                averageEngagement: 0.4,
                averageResponseLatency: latency,
                totalAnswerChanges: i % 2 == 0 ? 5 : 1,
                signalQuality: .good
            )
            sessions.append(session)
        }

        let results = engine.evaluate(sessions: sessions, userGroup: .child)
        let adhdResult = results.first { $0.condition == .adhd }

        XCTAssertNotNil(adhdResult)
        XCTAssertTrue(adhdResult?.isSufficientData ?? false)
    }

    func testNoADHDWithConsistentPerformance() {
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
                    responseLatency: 4.0  // Consistent
                ))
            }

            session.signalSummary = SessionSignalSummary(
                averageEngagement: 0.8,
                averageResponseLatency: 4.0,
                totalAnswerChanges: 0,
                signalQuality: .good
            )
            sessions.append(session)
        }

        let results = engine.evaluate(sessions: sessions, userGroup: .child)
        let adhdResult = results.first { $0.condition == .adhd }

        XCTAssertNotNil(adhdResult)
        XCTAssertFalse(adhdResult?.shouldRecommendProfessional ?? true,
                       "Consistent performance should not flag ADHD")
    }
}
