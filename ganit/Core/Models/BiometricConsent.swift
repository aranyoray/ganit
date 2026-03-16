import Foundation

// MARK: - Biometric Consent

/// Per-signal consent state for biometric data collection.
/// Stored in EncryptedStorage so consent choices are protected at rest.
struct BiometricConsent: Codable {
    var eyeTrackingEnabled: Bool = false
    var facialAnalysisEnabled: Bool = false
    var touchTrackingEnabled: Bool = true   // Default on (least invasive)
    var voiceTrackingEnabled: Bool = false
    var consentGrantedAt: Date?

    /// Returns true if any biometric signal is enabled.
    var hasAnyEnabled: Bool {
        eyeTrackingEnabled || facialAnalysisEnabled || touchTrackingEnabled || voiceTrackingEnabled
    }

    /// Returns true if the user has completed the initial consent flow at least once.
    var hasCompletedInitialConsent: Bool {
        consentGrantedAt != nil
    }

    // MARK: - Storage Key

    static let storageKey = "biometricConsent"
}
