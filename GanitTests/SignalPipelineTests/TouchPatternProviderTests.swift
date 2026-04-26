import XCTest
@testable import Ganit

final class TouchPatternProviderTests: XCTestCase {

    var provider: TouchPatternProvider!

    @MainActor
    override func setUp() {
        super.setUp()
        provider = TouchPatternProvider()
    }

    @MainActor
    func testResponseLatencyIsZeroBeforeInteraction() {
        provider.questionDidAppear()
        XCTAssertEqual(provider.responseLatency, 0, "Latency should be 0 before any touch")
    }

    @MainActor
    func testResponseLatencyMeasured() async {
        provider.questionDidAppear()
        // Simulate a brief delay
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        provider.optionSelected(index: 0)
        XCTAssertGreaterThan(provider.responseLatency, 0.05, "Latency should be > 0.05s after delay")
    }

    @MainActor
    func testAnswerChangeTracking() {
        provider.questionDidAppear()
        provider.optionSelected(index: 0)
        provider.optionDeselected(index: 0)
        provider.optionSelected(index: 1)
        XCTAssertEqual(provider.answerChangeCount, 1, "Should track 1 answer change")
        XCTAssertEqual(provider.currentHesitationCount, 1, "Should track 1 hesitation")
    }

    @MainActor
    func testResetOnNewQuestion() {
        provider.questionDidAppear()
        provider.optionSelected(index: 0)
        provider.optionDeselected(index: 0)
        provider.optionSelected(index: 1)

        // New question should reset
        provider.questionDidAppear()
        XCTAssertEqual(provider.currentHesitationCount, 0, "Should reset hesitation on new question")
        XCTAssertEqual(provider.answerChangeCount, 0, "Should reset answer changes on new question")
    }

    @MainActor
    func testSignalQualityAlwaysGood() {
        XCTAssertEqual(provider.signalQuality, .good, "Touch provider should always report good quality")
    }

    @MainActor
    func testIsAlwaysAvailable() {
        XCTAssertTrue(provider.isAvailable, "Touch provider should always be available")
    }
}
