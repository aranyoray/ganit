import XCTest
@testable import ganit

final class QuizViewModelTests: XCTestCase {

    var storage: MockStorage!
    var questionService: AIQuestionService!
    var progressState: ProgressState!
    var touchProvider: TouchPatternProvider!
    var viewModel: QuizViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        storage = MockStorage()
        questionService = AIQuestionService(storage: EncryptedStorage.shared)
        progressState = ProgressState(storage: storage)
        touchProvider = TouchPatternProvider()
        viewModel = QuizViewModel(
            mode: .addition,
            questionService: questionService,
            progressState: progressState,
            touchProvider: touchProvider
        )
    }

    // MARK: - State Machine

    @MainActor
    func testInitialStateIsIdle() {
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isAnswered)
        XCTAssertNil(viewModel.currentQuestion)
    }

    @MainActor
    func testSelectAnswerOnlyWorksWhenPresenting() {
        // Can't answer in idle state
        viewModel.selectAnswer(index: 0)
        XCTAssertEqual(viewModel.state, .idle, "Should not change state when not presenting")
    }

    @MainActor
    func testNextQuestionOnlyWorksWhenAnswered() {
        // Can't go next in idle state
        viewModel.nextQuestion()
        XCTAssertEqual(viewModel.state, .idle, "Should not change state when not answered")
    }

    @MainActor
    func testOfflineFallbackSetsPresenting() {
        viewModel.switchToOffline()
        XCTAssertTrue(viewModel.useFallback)
        if case .presenting(let q) = viewModel.state {
            XCTAssertFalse(q.question.isEmpty)
        } else {
            XCTFail("Should be presenting a fallback question")
        }
    }

    @MainActor
    func testSelectAnswerTransitionsToAnswered() {
        viewModel.switchToOffline()
        guard case .presenting = viewModel.state else {
            XCTFail("Should be presenting")
            return
        }

        viewModel.selectAnswer(index: 0)
        if case .answered = viewModel.state {
            // Good
        } else {
            XCTFail("Should transition to answered state")
        }
        XCTAssertTrue(viewModel.isAnswered)
    }

    @MainActor
    func testCorrectAnswerIncreasesScore() {
        viewModel.switchToOffline()
        guard case .presenting(let q) = viewModel.state else { return }

        let scoreBefore = progressState.score
        viewModel.selectAnswer(index: q.correct_index)
        XCTAssertGreaterThan(progressState.score, scoreBefore)
    }

    @MainActor
    func testWrongAnswerDecreasesScore() {
        progressState.score = 10
        viewModel.switchToOffline()
        guard case .presenting(let q) = viewModel.state else { return }

        let wrongIndex = (q.correct_index + 1) % q.options.count
        viewModel.selectAnswer(index: wrongIndex)
        XCTAssertLessThan(progressState.score, 10)
    }

    @MainActor
    func testStreakResetsOnWrongAnswer() {
        viewModel.streak = 5
        viewModel.switchToOffline()
        guard case .presenting(let q) = viewModel.state else { return }

        let wrongIndex = (q.correct_index + 1) % q.options.count
        viewModel.selectAnswer(index: wrongIndex)
        XCTAssertEqual(viewModel.streak, 0)
    }

    @MainActor
    func testHintShowsOnWrongAnswer() {
        viewModel.switchToOffline()
        guard case .presenting(let q) = viewModel.state else { return }

        let wrongIndex = (q.correct_index + 1) % q.options.count
        viewModel.selectAnswer(index: wrongIndex)
        XCTAssertTrue(viewModel.showHint)
    }

    @MainActor
    func testNextQuestionResetsState() {
        viewModel.switchToOffline()
        guard case .presenting(let q) = viewModel.state else { return }

        viewModel.selectAnswer(index: q.correct_index)
        viewModel.nextQuestion()

        XCTAssertNil(viewModel.selectedIndex)
        XCTAssertFalse(viewModel.showHint)
        XCTAssertTrue(viewModel.resultMessage.isEmpty)
    }

    // MARK: - Mode Properties

    @MainActor
    func testModeProperties() {
        XCTAssertEqual(viewModel.mode, .addition)
        XCTAssertEqual(viewModel.mode.pointMultiplier, 1)
        XCTAssertEqual(viewModel.mode.xpReward, 50)
    }
}
