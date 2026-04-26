import Foundation

// MARK: - Engagement Classifier

/// Classifies engagement state from signal snapshots.
/// V1: Rule-based heuristics. V2: CoreML model.
struct EngagementClassifier {

    /// Classify the overall engagement state from a snapshot.
    static func classify(_ snapshot: SignalSnapshot) -> EngagementState {
        // Dominant signal determines state
        if snapshot.frustrationScore > 0.5 {
            return .frustrated
        }
        if snapshot.confusionScore > 0.5 {
            return .confused
        }
        if snapshot.anxietyScore > 0.5 {
            return .anxious
        }
        if snapshot.engagementScore > 0.6 {
            return .engaged
        }
        if snapshot.engagementScore < 0.3 {
            return .disengaged
        }
        return .neutral
    }

    /// Weighted classification using recent history for smoother transitions.
    static func classifyWithHistory(_ snapshots: [SignalSnapshot], windowSize: Int = 3) -> EngagementState {
        let recent = Array(snapshots.suffix(windowSize))
        guard !recent.isEmpty else { return .neutral }

        let avgEngagement = recent.map(\.engagementScore).reduce(0, +) / Float(recent.count)
        let avgConfusion = recent.map(\.confusionScore).reduce(0, +) / Float(recent.count)
        let avgFrustration = recent.map(\.frustrationScore).reduce(0, +) / Float(recent.count)
        let avgAnxiety = recent.map(\.anxietyScore).reduce(0, +) / Float(recent.count)

        // Use averaged signals
        var composite = recent.last!
        composite.engagementScore = avgEngagement
        composite.confusionScore = avgConfusion
        composite.frustrationScore = avgFrustration
        composite.anxietyScore = avgAnxiety

        return classify(composite)
    }
}

// MARK: - Engagement State

enum EngagementState: String, Codable {
    case engaged
    case confused
    case frustrated
    case anxious
    case disengaged
    case neutral
}
