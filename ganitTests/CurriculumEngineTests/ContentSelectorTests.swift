import XCTest
@testable import Ganit

final class ContentSelectorTests: XCTestCase {

    func testChildContentIsMathMCQ() {
        let config = ContentSelector.selectContent(
            state: CurriculumState(contentType: .mathMCQ),
            userGroup: .child
        )
        XCTAssertEqual(config.contentType, .mathMCQ)
    }

    func testElderlyContentIsCognitive() {
        let config = ContentSelector.selectContent(
            state: CurriculumState(contentType: .cognitiveMemory),
            userGroup: .elderly
        )
        XCTAssertTrue(
            [ContentType.cognitiveMemory, .cognitivePattern, .cognitiveWordPuzzle].contains(config.contentType),
            "Elderly content should be cognitive exercises"
        )
    }

    func testDifficultyMappingFromAccuracy() {
        XCTAssertEqual(DifficultyLevel.from(accuracy: 0.3), .veryEasy)
        XCTAssertEqual(DifficultyLevel.from(accuracy: 0.5), .easy)
        XCTAssertEqual(DifficultyLevel.from(accuracy: 0.7), .medium)
        XCTAssertEqual(DifficultyLevel.from(accuracy: 0.85), .challenging)
        XCTAssertEqual(DifficultyLevel.from(accuracy: 0.95), .hard)
    }

    func testGradeFromLevel() {
        XCTAssertEqual(gradeFromLevel(0), 1)
        XCTAssertEqual(gradeFromLevel(3), 1)
        XCTAssertEqual(gradeFromLevel(10), 2)
        XCTAssertEqual(gradeFromLevel(25), 3)
        XCTAssertEqual(gradeFromLevel(40), 4)
        XCTAssertEqual(gradeFromLevel(60), 5)
        XCTAssertEqual(gradeFromLevel(100), 6)
        XCTAssertEqual(gradeFromLevel(150), 7)
    }

    func testQuizModeProperties() {
        XCTAssertEqual(QuizMode.addition.symbol, "+")
        XCTAssertEqual(QuizMode.addition.pointMultiplier, 1)
        XCTAssertEqual(QuizMode.multiplication.pointMultiplier, 5)
        XCTAssertEqual(QuizMode.division.xpReward, 150)

        XCTAssertEqual(QuizMode(from: "+"), .addition)
        XCTAssertEqual(QuizMode(from: "-"), .subtraction)
        XCTAssertEqual(QuizMode(from: "*"), .multiplication)
        XCTAssertEqual(QuizMode(from: "/"), .division)
        XCTAssertNil(QuizMode(from: "x"))
    }
}
