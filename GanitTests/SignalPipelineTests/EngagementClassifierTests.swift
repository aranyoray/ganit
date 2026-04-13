import XCTest
@testable import Ganit

final class EngagementClassifierTests: XCTestCase {

    func testFrustratedClassification() {
        var snapshot = SignalSnapshot(timestamp: Date(), questionId: "test")
        snapshot.frustrationScore = 0.7
        snapshot.engagementScore = 0.3

        let state = EngagementClassifier.classify(snapshot)
        XCTAssertEqual(state, .frustrated)
    }

    func testConfusedClassification() {
        var snapshot = SignalSnapshot(timestamp: Date(), questionId: "test")
        snapshot.confusionScore = 0.6
        snapshot.frustrationScore = 0.2
        snapshot.engagementScore = 0.4

        let state = EngagementClassifier.classify(snapshot)
        XCTAssertEqual(state, .confused)
    }

    func testEngagedClassification() {
        var snapshot = SignalSnapshot(timestamp: Date(), questionId: "test")
        snapshot.engagementScore = 0.8
        snapshot.confusionScore = 0.1
        snapshot.frustrationScore = 0.1

        let state = EngagementClassifier.classify(snapshot)
        XCTAssertEqual(state, .engaged)
    }

    func testDisengagedClassification() {
        var snapshot = SignalSnapshot(timestamp: Date(), questionId: "test")
        snapshot.engagementScore = 0.1
        snapshot.confusionScore = 0.2
        snapshot.frustrationScore = 0.2

        let state = EngagementClassifier.classify(snapshot)
        XCTAssertEqual(state, .disengaged)
    }

    func testNeutralClassification() {
        var snapshot = SignalSnapshot(timestamp: Date(), questionId: "test")
        snapshot.engagementScore = 0.5
        snapshot.confusionScore = 0.2
        snapshot.frustrationScore = 0.2

        let state = EngagementClassifier.classify(snapshot)
        XCTAssertEqual(state, .neutral)
    }

    func testHistoryBasedClassificationSmooths() {
        // Create snapshots with varying engagement
        var snapshots: [SignalSnapshot] = []
        for i in 0..<5 {
            var s = SignalSnapshot(timestamp: Date(), questionId: "q\(i)")
            s.engagementScore = i < 3 ? 0.8 : 0.2  // First 3 engaged, last 2 not
            snapshots.append(s)
        }

        // With window of 3, should consider last 3 (0.8, 0.2, 0.2 = avg 0.4)
        let state = EngagementClassifier.classifyWithHistory(snapshots, windowSize: 3)
        // Average engagement ~0.4, should be neutral or disengaged
        XCTAssertTrue(state == .neutral || state == .disengaged)
    }
}
