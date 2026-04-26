import Foundation

// MARK: - Content Selector

/// Selects appropriate content based on user group, curriculum state, and progress.
/// For children: math MCQs based on QuizMode, grade level, and difficulty.
/// For elderly: cognitive exercises (memory, pattern recognition, word puzzles).
@MainActor
final class ContentSelector {

    // MARK: - Content Configuration

    /// Describes what content to present next.
    struct ContentConfiguration {
        let contentType: ContentType
        let difficulty: DifficultyLevel
        let accommodations: [Accommodation]

        // Child-specific
        var quizMode: QuizMode?
        var grade: Int?

        // Elderly cognitive exercise-specific
        var exerciseConfig: CognitiveExerciseConfig?
    }

    /// Configuration for a cognitive exercise (elderly path).
    struct CognitiveExerciseConfig {
        let exerciseType: CognitiveExerciseType
        let sequenceLength: Int       // Memory: how many items to recall
        let optionCount: Int           // Pattern/word: how many choices
        let timeLimit: TimeInterval?   // nil means no time pressure
    }

    /// Types of cognitive exercises for elderly users.
    enum CognitiveExerciseType: String, CaseIterable {
        case memorySequence
        case patternRecognition
        case wordPuzzle
    }

    // MARK: - Dependencies

    private let curriculumState: CurriculumState
    private let userGroup: UserGroup

    // MARK: - Init

    init(curriculumState: CurriculumState, userGroup: UserGroup) {
        self.curriculumState = curriculumState
        self.userGroup = userGroup
    }

    // MARK: - Selection

    /// Returns the next content configuration based on current curriculum state and user group.
    func selectContent(
        quizMode: QuizMode? = nil,
        progressState: ProgressState? = nil
    ) -> ContentConfiguration {
        switch userGroup {
        case .child:
            return selectChildContent(quizMode: quizMode, progressState: progressState)
        case .elderly:
            return selectElderlyContent()
        }
    }

    // MARK: - Child Content

    private func selectChildContent(
        quizMode: QuizMode?,
        progressState: ProgressState?
    ) -> ContentConfiguration {
        let mode = quizMode ?? .addition
        let level = progressState?.levelFor(mode: mode) ?? 0
        let grade = gradeFromLevel(level)

        return ContentConfiguration(
            contentType: .mathMCQ,
            difficulty: curriculumState.difficulty,
            accommodations: curriculumState.accommodations,
            quizMode: mode,
            grade: grade,
            exerciseConfig: nil
        )
    }

    // MARK: - Elderly Content

    private func selectElderlyContent() -> ContentConfiguration {
        let exerciseType = selectExerciseType()
        let config = buildExerciseConfig(for: exerciseType)

        // Merge accommodations: always include elderly defaults
        var accommodations = curriculumState.accommodations
        if !accommodations.contains(.largerText) {
            accommodations.append(.largerText)
        }
        if !accommodations.contains(.highContrast) {
            accommodations.append(.highContrast)
        }
        if !accommodations.contains(.extendedTime) {
            accommodations.append(.extendedTime)
        }

        return ContentConfiguration(
            contentType: contentTypeFor(exerciseType),
            difficulty: curriculumState.difficulty,
            accommodations: accommodations,
            quizMode: nil,
            grade: nil,
            exerciseConfig: config
        )
    }

    /// Selects which cognitive exercise type based on current content type in curriculum state.
    private func selectExerciseType() -> CognitiveExerciseType {
        switch curriculumState.contentType {
        case .cognitiveMemory:
            return .memorySequence
        case .cognitivePattern:
            return .patternRecognition
        case .cognitiveWordPuzzle:
            return .wordPuzzle
        default:
            // Rotate through exercise types for variety
            return CognitiveExerciseType.allCases.randomElement() ?? .memorySequence
        }
    }

    /// Builds exercise parameters scaled to current difficulty.
    private func buildExerciseConfig(for type: CognitiveExerciseType) -> CognitiveExerciseConfig {
        let difficulty = curriculumState.difficulty
        let hasExtendedTime = curriculumState.accommodations.contains(.extendedTime)

        switch type {
        case .memorySequence:
            let length = sequenceLengthForDifficulty(difficulty)
            return CognitiveExerciseConfig(
                exerciseType: .memorySequence,
                sequenceLength: length,
                optionCount: 0,
                timeLimit: hasExtendedTime ? nil : timeLimitForDifficulty(difficulty)
            )

        case .patternRecognition:
            return CognitiveExerciseConfig(
                exerciseType: .patternRecognition,
                sequenceLength: patternLengthForDifficulty(difficulty),
                optionCount: optionCountForDifficulty(difficulty),
                timeLimit: hasExtendedTime ? nil : timeLimitForDifficulty(difficulty)
            )

        case .wordPuzzle:
            return CognitiveExerciseConfig(
                exerciseType: .wordPuzzle,
                sequenceLength: wordCountForDifficulty(difficulty),
                optionCount: optionCountForDifficulty(difficulty),
                timeLimit: hasExtendedTime ? nil : timeLimitForDifficulty(difficulty)
            )
        }
    }

    // MARK: - Difficulty Scaling

    private func sequenceLengthForDifficulty(_ difficulty: DifficultyLevel) -> Int {
        switch difficulty {
        case .veryEasy:    return 3
        case .easy:        return 4
        case .medium:      return 5
        case .challenging: return 6
        case .hard:        return 7
        }
    }

    private func patternLengthForDifficulty(_ difficulty: DifficultyLevel) -> Int {
        switch difficulty {
        case .veryEasy:    return 3
        case .easy:        return 4
        case .medium:      return 4
        case .challenging: return 5
        case .hard:        return 6
        }
    }

    private func optionCountForDifficulty(_ difficulty: DifficultyLevel) -> Int {
        switch difficulty {
        case .veryEasy:    return 3
        case .easy:        return 3
        case .medium:      return 4
        case .challenging: return 4
        case .hard:        return 5
        }
    }

    private func wordCountForDifficulty(_ difficulty: DifficultyLevel) -> Int {
        switch difficulty {
        case .veryEasy:    return 4
        case .easy:        return 4
        case .medium:      return 5
        case .challenging: return 5
        case .hard:        return 6
        }
    }

    private func timeLimitForDifficulty(_ difficulty: DifficultyLevel) -> TimeInterval {
        switch difficulty {
        case .veryEasy:    return 30
        case .easy:        return 25
        case .medium:      return 20
        case .challenging: return 15
        case .hard:        return 12
        }
    }

    private func contentTypeFor(_ exerciseType: CognitiveExerciseType) -> ContentType {
        switch exerciseType {
        case .memorySequence:      return .cognitiveMemory
        case .patternRecognition:  return .cognitivePattern
        case .wordPuzzle:          return .cognitiveWordPuzzle
        }
    }
}
