import XCTest
@testable import Ganit

final class AdaptiveEngineTests: XCTestCase {

    @MainActor
    func testDifficultyDropsWhenFrustrated() {
        let engine = AdaptiveEngine(userGroup: .child)
        var snapshot = SignalSnapshot(timestamp: Date(), questionId: "test")
        snapshot.frustrationScore = 0.7

        engine.adapt(engagement: .frustrated, snapshot: snapshot, accuracy: 0.6)

        XCTAssertLessThanOrEqual(
            engine.currentState.difficulty.numericValue,
            DifficultyLevel.easy.numericValue,
            "Difficulty should drop when frustrated"
        )
    }

    @MainActor
    func testAnxietyFriendlyAddedWhenAnxious() {
        let engine = AdaptiveEngine(userGroup: .child)
        var snapshot = SignalSnapshot(timestamp: Date(), questionId: "test")
        snapshot.anxietyScore = 0.7

        engine.adapt(engagement: .anxious, snapshot: snapshot, accuracy: 0.5)

        XCTAssertTrue(
            engine.currentState.accommodations.contains(.anxietyFriendly),
            "Should add anxiety-friendly accommodation"
        )
        XCTAssertTrue(
            engine.currentState.accommodations.contains(.extendedTime),
            "Should add extended time accommodation"
        )
    }

    @MainActor
    func testVoiceInstructionsAddedWhenConfused() {
        let engine = AdaptiveEngine(userGroup: .child)
        var snapshot = SignalSnapshot(timestamp: Date(), questionId: "test")
        snapshot.confusionScore = 0.6

        engine.adapt(engagement: .confused, snapshot: snapshot, accuracy: 0.5)

        XCTAssertTrue(
            engine.currentState.accommodations.contains(.voiceInstructions),
            "Should add voice instructions when confused"
        )
    }

    @MainActor
    func testARSuggestedWhenDisengaged() {
        let engine = AdaptiveEngine(userGroup: .child)
        var snapshot = SignalSnapshot(timestamp: Date(), questionId: "test")
        snapshot.engagementScore = 0.1

        engine.adapt(engagement: .disengaged, snapshot: snapshot, accuracy: 0.5)

        XCTAssertNotEqual(
            engine.currentState.preferredModality,
            .standard2D,
            "Should suggest AR mode when disengaged"
        )
    }

    @MainActor
    func testElderlyDefaultAccommodations() {
        let engine = AdaptiveEngine(userGroup: .elderly)

        XCTAssertTrue(engine.currentState.accommodations.contains(.largerText))
        XCTAssertTrue(engine.currentState.accommodations.contains(.highContrast))
        XCTAssertTrue(engine.currentState.accommodations.contains(.extendedTime))
    }

    @MainActor
    func testChildDefaultContentType() {
        let engine = AdaptiveEngine(userGroup: .child)
        XCTAssertEqual(engine.currentState.contentType, .mathMCQ)
    }

    @MainActor
    func testElderlyDefaultContentType() {
        let engine = AdaptiveEngine(userGroup: .elderly)
        XCTAssertEqual(engine.currentState.contentType, .cognitiveMemory)
    }
}
