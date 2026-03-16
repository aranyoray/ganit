import SwiftUI
import Combine

// MARK: - Biometric Consent View Model

@MainActor
class BiometricConsentViewModel: ObservableObject {
    @Published var consent: BiometricConsent

    private let storage: StorageProvider
    private let username: String

    init(storage: StorageProvider, username: String) {
        self.storage = storage
        self.username = username
        self.consent = storage.readCodable(
            BiometricConsent.storageKey,
            as: BiometricConsent.self,
            user: username
        ) ?? BiometricConsent()
    }

    var hasCompletedInitialConsent: Bool {
        consent.hasCompletedInitialConsent
    }

    func saveConsent() {
        consent.consentGrantedAt = Date()
        storage.saveCodable(BiometricConsent.storageKey, value: consent, user: username)
    }

    func updateConsent() {
        storage.saveCodable(BiometricConsent.storageKey, value: consent, user: username)
    }
}

// MARK: - Biometric Consent View

struct BiometricConsentView: View {
    @ObservedObject var viewModel: BiometricConsentViewModel
    var onComplete: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Text("Privacy Choices")
                .font(.title2.bold())

            Text("Choose what Ganit can observe while you learn.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Toggle("Eye Tracking", isOn: $viewModel.consent.eyeTrackingEnabled)
            Toggle("Face Expressions", isOn: $viewModel.consent.facialAnalysisEnabled)
            Toggle("Touch Patterns", isOn: $viewModel.consent.touchTrackingEnabled)
            Toggle("Voice Analysis", isOn: $viewModel.consent.voiceTrackingEnabled)

            Spacer()

            Button("Continue") {
                viewModel.saveConsent()
                onComplete?()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Privacy Choices")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
