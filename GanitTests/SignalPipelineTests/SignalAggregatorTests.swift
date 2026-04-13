import XCTest
@testable import Ganit

final class SignalAggregatorTests: XCTestCase {

    var touchProvider: TouchPatternProvider!
    var aggregator: SignalAggregator!

    @MainActor
    override func setUp() {
        super.setUp()
        touchProvider = TouchPatternProvider()
        aggregator = SignalAggregator(touchProvider: touchProvider)
    }

    @MainActor
    func testSnapshotCaptureWithNoInteraction() {
        touchProvider.questionDidAppear()
        let snapshot = aggregator.captureSnapshot(questionId: "test_q1")

        XCTAssertEqual(snapshot.questionId, "test_q1")
        XCTAssertEqual(snapshot.hesitationCount, 0)
        XCTAssertEqual(snapshot.answerChanges, 0)
    }

    @MainActor
    func testEngagementScoreHighForQuickResponse() async {
        touchProvider.questionDidAppear()
        // Immediate response
        touchProvider.optionSelected(index: 0)
        touchProvider.answerSubmitted()

        let snapshot = aggregator.captureSnapshot(questionId: "test_quick")

        // Quick response with no hesitation should have high engagement
        XCTAssertGreaterThan(snapshot.engagementScore, 0.5, "Quick response should show high engagement")
    }

    @MainActor
    func testConfusionScoreHighForManyChanges() {
        touchProvider.questionDidAppear()
        touchProvider.optionSelected(index: 0)
        touchProvider.optionDeselected(index: 0)
        touchProvider.optionSelected(index: 1)
        touchProvider.optionDeselected(index: 1)
        touchProvider.optionSelected(index: 2)
        touchProvider.optionDeselected(index: 2)
        touchProvider.optionSelected(index: 3)
        touchProvider.answerSubmitted()

        let snapshot = aggregator.captureSnapshot(questionId: "test_confused")
        XCTAssertGreaterThan(snapshot.confusionScore, 0.3, "Many answer changes should indicate confusion")
    }

    @MainActor
    func testLatestSnapshotUpdated() {
        touchProvider.questionDidAppear()
        XCTAssertNil(aggregator.latestSnapshot)

        _ = aggregator.captureSnapshot(questionId: "test_update")
        XCTAssertNotNil(aggregator.latestSnapshot)
        XCTAssertEqual(aggregator.latestSnapshot?.questionId, "test_update")
    }
}
