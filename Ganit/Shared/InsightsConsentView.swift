import SwiftUI

/// One-time consent acknowledgment before showing learning pattern results.
struct InsightsConsentView: View {
    let onConsent: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("Learning Pattern Insights")
                .font(.title2.bold())

            Text("Ganit analyzes interaction patterns to provide educational observations about learning styles and progress.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            LearningInsightsDisclaimerView()

            VStack(alignment: .leading, spacing: 8) {
                Text("By continuing, you acknowledge:")
                    .font(.subheadline.bold())

                bulletPoint("These insights are educational observations, not medical diagnoses")
                bulletPoint("They should not replace professional evaluation")
                bulletPoint("They are based on interaction patterns within the app")
                bulletPoint("You can disable insights at any time")
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)

            Button("I Understand — Show Insights") {
                onConsent()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Manages consent state for learning insights.
@MainActor
class InsightsConsentManager: ObservableObject {
    @Published var hasConsented: Bool = false

    private let storage: EncryptedStorage
    private let user: String
    private static let consentKey = "insightsConsent"

    init(storage: EncryptedStorage = .shared, user: String) {
        self.storage = storage
        self.user = user
        self.hasConsented = loadConsent()
    }

    func grantConsent() {
        hasConsented = true
        storage.save(Self.consentKey, value: "granted", user: user)
    }

    func revokeConsent() {
        hasConsented = false
        storage.save(Self.consentKey, value: "", user: user)
    }

    private func loadConsent() -> Bool {
        storage.read(Self.consentKey, user: user) == "granted"
    }
}
