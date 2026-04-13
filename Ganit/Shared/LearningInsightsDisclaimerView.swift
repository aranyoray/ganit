import SwiftUI

/// Reusable disclaimer banner for learning insights sections.
struct LearningInsightsDisclaimerView: View {
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
            Text(compact ? LearningInsightsDisclaimer.short : LearningInsightsDisclaimer.text)
                .font(compact ? .caption2 : .caption)
                .foregroundColor(.secondary)
        }
        .padding(compact ? 8 : 12)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}
