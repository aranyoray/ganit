import Foundation

// MARK: - Adaptive Engine

/// Core adaptation coordinator. Takes engagement signals and adjusts curriculum.
/// V1: Extends accuracy-to-difficulty with touch signal inputs.
@MainActor
class AdaptiveEngine: ObservableObject {

    @Published var currentState: CurriculumState

    private let userGroup: UserGroup

    init(userGroup: UserGroup) {
        self.userGroup = userGroup

        // Default accommodations by user group
        var accommodations: [Accommodation] = []
        if userGroup == .elderly {
            accommodations = [.largerText, .highContrast, .extendedTime]
        }

        self.currentState = CurriculumState(
            difficulty: .medium,
            contentType: userGroup == .child ? .mathMCQ : .cognitiveMemory,
            preferredModality: .standard2D,
            accommodations: accommodations
        )
    }

    /// Adapt curriculum based on the latest engagement state and signal snapshot.
    func adapt(engagement: EngagementState, snapshot: SignalSnapshot, accuracy: Double) {
        // Difficulty adjustment based on accuracy (existing logic from ganit_base)
        var newDifficulty = DifficultyLevel.from(accuracy: accuracy)

        // Signal-based adjustments override pure accuracy
        switch engagement {
        case .frustrated:
            // Drop difficulty by one level
            if newDifficulty > .veryEasy {
                newDifficulty = DifficultyLevel(rawValue: ["very easy", "easy", "medium", "challenging", "hard"][max(0, newDifficulty.numericValue - 1)]) ?? .easy
            }
            // Add anxiety-friendly accommodations
            if !currentState.accommodations.contains(.anxietyFriendly) {
                currentState.accommodations.append(.anxietyFriendly)
            }

        case .confused:
            // Show more hints, possibly switch to AR mode
            if newDifficulty > .easy {
                newDifficulty = DifficultyLevel(rawValue: ["very easy", "easy", "medium", "challenging", "hard"][max(0, newDifficulty.numericValue - 1)]) ?? .easy
            }
            // Enable voice instructions
            if !currentState.accommodations.contains(.voiceInstructions) {
                currentState.accommodations.append(.voiceInstructions)
            }

        case .disengaged:
            // Might benefit from AR mode for engagement
            if currentState.preferredModality == .standard2D {
                currentState.preferredModality = .arBasic
            }

        case .engaged:
            // Remove unnecessary accommodations gradually
            currentState.accommodations.removeAll { $0 == .anxietyFriendly }

        case .anxious:
            // Maximum support
            if !currentState.accommodations.contains(.anxietyFriendly) {
                currentState.accommodations.append(.anxietyFriendly)
            }
            if !currentState.accommodations.contains(.extendedTime) {
                currentState.accommodations.append(.extendedTime)
            }

        case .neutral:
            break
        }

        currentState.difficulty = newDifficulty
    }

    /// Check if haptic hints should be enabled based on current state.
    var shouldUseHapticHints: Bool {
        currentState.accommodations.contains(.hapticHints) ||
        currentState.difficulty <= .easy
    }

    /// Check if AR mode is recommended.
    var shouldSuggestAR: Bool {
        currentState.preferredModality != .standard2D
    }
}
