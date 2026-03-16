import Foundation

// MARK: - Curriculum State

/// Represents where the learner is in the curriculum and how content should be presented.
struct CurriculumState: Codable {
    var difficulty: DifficultyLevel
    var contentType: ContentType
    var preferredModality: LearningModality
    var accommodations: [Accommodation]

    init(
        difficulty: DifficultyLevel = .medium,
        contentType: ContentType = .mathMCQ,
        preferredModality: LearningModality = .standard2D,
        accommodations: [Accommodation] = []
    ) {
        self.difficulty = difficulty
        self.contentType = contentType
        self.preferredModality = preferredModality
        self.accommodations = accommodations
    }
}

// MARK: - Difficulty

enum DifficultyLevel: String, Codable, Comparable {
    case veryEasy = "very easy"
    case easy
    case medium
    case challenging
    case hard

    static func < (lhs: DifficultyLevel, rhs: DifficultyLevel) -> Bool {
        lhs.numericValue < rhs.numericValue
    }

    var numericValue: Int {
        switch self {
        case .veryEasy:    return 0
        case .easy:        return 1
        case .medium:      return 2
        case .challenging: return 3
        case .hard:        return 4
        }
    }

    /// Maps accuracy (0-1) to a difficulty level.
    static func from(accuracy: Double) -> DifficultyLevel {
        switch accuracy {
        case ..<0.4:       return .veryEasy
        case 0.4..<0.6:    return .easy
        case 0.6..<0.75:   return .medium
        case 0.75..<0.9:   return .challenging
        default:           return .hard
        }
    }
}

// MARK: - Content Type

enum ContentType: String, Codable {
    case mathMCQ
    case englishVocab
    case englishReading
    case cognitiveMemory
    case cognitivePattern
    case cognitiveWordPuzzle
}

// MARK: - Learning Modality

enum LearningModality: String, Codable {
    case standard2D           // Normal quiz view
    case arBasic              // V1: 3D number blocks
    case arInteractive        // V2: Drag/combine
    case arImmersive          // V3: Walk-around
}

// MARK: - Accommodations

enum Accommodation: String, Codable {
    case extendedTime         // No time pressure
    case largerText           // Accessibility
    case highContrast         // Visual accessibility
    case reducedAnimations    // Motion sensitivity
    case anxietyFriendly      // Soft colors, no red wrong indicators
    case voiceInstructions    // AVSpeechSynthesizer guidance
    case hapticHints          // Warmer/colder feedback
}

// MARK: - Grade Mapping

/// Maps a level number to a school grade.
func gradeFromLevel(_ level: Int) -> Int {
    switch level {
    case 0..<5:    return 1
    case 5..<15:   return 2
    case 15..<30:  return 3
    case 30..<50:  return 4
    case 50..<80:  return 5
    case 80..<120: return 6
    default:       return 7
    }
}
