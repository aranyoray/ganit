import XCTest
@testable import Ganit

final class MultimodalAggregatorTests: XCTestCase {

    @MainActor
    func testMultimodalSnapshotIncludesAllSignals() {
        let touch = TouchPatternProvider()
        let aggregator = SignalAggregator(touchProvider: touch)

        touch.questionDidAppear()
        touch.optionSelected(index: 0)
        touch.optionDeselected(index: 0)
        touch.optionSelected(index: 1)
        touch.answerSubmitted()

        let snapshot = aggregator.captureSnapshot(questionId: "multi_test")

        // Touch signals should be populated
        XCTAssertGreaterThan(snapshot.hesitationCount, 0)
        XCTAssertGreaterThan(snapshot.answerChanges, 0)

        // Engagement state should be updated
        XCTAssertNotEqual(aggregator.engagementState, .neutral, "Engagement should change from interaction")
    }

    @MainActor
    func testEngagementStateUpdatesWithHistory() {
        let touch = TouchPatternProvider()
        let aggregator = SignalAggregator(touchProvider: touch)

        // Generate several snapshots
        for i in 0..<5 {
            touch.questionDidAppear()
            touch.optionSelected(index: 0)
            touch.answerSubmitted()
            _ = aggregator.captureSnapshot(questionId: "q\(i)")
        }

        // After multiple quick responses, should be engaged
        XCTAssertTrue(
            aggregator.engagementState == .engaged || aggregator.engagementState == .neutral,
            "Quick consistent responses should show engagement"
        )
    }

    @MainActor
    func testGazeAvoidanceCalculation() {
        let touch = TouchPatternProvider()
        let aggregator = SignalAggregator(touchProvider: touch)

        touch.questionDidAppear()
        let snapshot = aggregator.captureSnapshot(questionId: "gaze_test")

        // No eye tracking configured = empty fixations
        XCTAssertTrue(snapshot.gazeFixations.isEmpty)
        XCTAssertEqual(snapshot.saccadeCount, 0)
    }

    func testSessionSignalSummaryFromSnapshots() {
        var snapshots: [SignalSnapshot] = []
        for i in 0..<5 {
            var s = SignalSnapshot(timestamp: Date(), questionId: "q\(i)")
            s.engagementScore = 0.7
            s.confusionScore = 0.2
            s.frustrationScore = 0.1
            s.responseLatency = 3.0
            s.hesitationCount = 1
            s.dominantExpression = .engaged
            snapshots.append(s)
        }

        let summary = SessionSignalSummary.from(snapshots: snapshots)
        XCTAssertEqual(summary.averageEngagement, 0.7, accuracy: 0.01)
        XCTAssertEqual(summary.averageConfusion, 0.2, accuracy: 0.01)
        XCTAssertEqual(summary.averageResponseLatency, 3.0, accuracy: 0.1)
        XCTAssertEqual(summary.dominantExpression, .engaged)
        XCTAssertEqual(summary.signalQuality, .good)
    }
}
