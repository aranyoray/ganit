import SwiftUI

// MARK: - Debug Overlay

/// Real-time signal visualization overlay. First-class demo feature.
/// Shows gaze, expression, touch, engagement, risk, and difficulty data.
/// Reusable as "teacher mode" later.
struct DebugOverlayView: View {
    let snapshot: SignalSnapshot?
    let engagementState: EngagementState
    let difficulty: DifficultyLevel
    let sessionCount: Int
    let isVisible: Bool

    var body: some View {
        if isVisible, let snapshot = snapshot {
            VStack(alignment: .leading, spacing: 4) {
                // Eye tracking (V2 placeholder)
                Label("Gaze: \(gazeText(snapshot))", systemImage: "eye")
                    .foregroundColor(.blue)

                // Expression
                Label("Expression: \(snapshot.dominantExpression.rawValue) (\(String(format: "%.2f", snapshot.expressionConfidence)))", systemImage: "face.smiling")
                    .foregroundColor(expressionColor(snapshot.dominantExpression))

                // Touch patterns
                Label("Touch: \(touchText(snapshot))", systemImage: "hand.tap")
                    .foregroundColor(.purple)

                // Engagement
                Label("Engagement: \(String(format: "%.2f", snapshot.engagementScore)) (\(engagementState.rawValue))", systemImage: "brain")
                    .foregroundColor(engagementColor(engagementState))

                // Risk tracking
                Label("Risk: session \(sessionCount)/10 \(sessionCount < 10 ? "(need more)" : "")", systemImage: "chart.bar")
                    .foregroundColor(.gray)

                // Difficulty
                Label("Difficulty: \(difficulty.rawValue)", systemImage: "bolt")
                    .foregroundColor(.orange)
            }
            .font(.caption)
            .padding(8)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .padding(8)
        }
    }

    // MARK: - Helpers

    private func gazeText(_ snapshot: SignalSnapshot) -> String {
        if snapshot.gazeFixations.isEmpty {
            return "no data (V2)"
        }
        if let last = snapshot.gazeFixations.last {
            return "\(last.region.rawValue) (\(String(format: "%.1f", last.duration))s)"
        }
        return "unknown"
    }

    private func touchText(_ snapshot: SignalSnapshot) -> String {
        var parts: [String] = []
        if snapshot.hesitationCount > 0 {
            parts.append("hesitating (\(snapshot.hesitationCount))")
        }
        if snapshot.answerChanges > 0 {
            parts.append("\(snapshot.answerChanges) changes")
        }
        if snapshot.responseLatency > 0 {
            parts.append("\(String(format: "%.1f", snapshot.responseLatency))s latency")
        }
        return parts.isEmpty ? "waiting" : parts.joined(separator: ", ")
    }

    private func expressionColor(_ expression: ExpressionCategory) -> Color {
        switch expression {
        case .engaged:    return .green
        case .confused:   return .orange
        case .frustrated: return .red
        case .anxious:    return .yellow
        case .bored:      return .gray
        case .neutral:    return .secondary
        case .ambiguous:  return .secondary
        }
    }

    private func engagementColor(_ state: EngagementState) -> Color {
        switch state {
        case .engaged:     return .green
        case .confused:    return .orange
        case .frustrated:  return .red
        case .anxious:     return .yellow
        case .disengaged:  return .gray
        case .neutral:     return .secondary
        }
    }
}
