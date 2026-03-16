import Foundation
import Combine
import FirebaseFunctions

// MARK: - Firebase COPPA Verification Service

/// Calls Firebase Cloud Functions for COPPA email verification.
/// Replaces on-device COPPAVerificationService with server-side code generation + SMTP.
///
/// ```
/// iOS App                          Firebase Cloud Functions
/// ────────                         ───────────────────────
/// sendCode(email) ──────────────▶  sendVerificationCode()
///                                    ├─ generate 6-digit code
///                                    ├─ hash + store in Firestore
///                                    └─ send via SMTP ──▶ parent's inbox
///
/// verifyCode(email, code) ──────▶  verifyCode()
///                                    ├─ lookup hash in Firestore
///                                    ├─ constant-time compare
///                                    └─ return verified: true/false
/// ```
@MainActor
class FirebaseCOPPAService: ObservableObject {

    @Published var state: VerificationState = .enterEmail
    @Published var errorMessage: String?
    @Published var sendCooldownRemaining: Int = 0
    @Published var verifyAttemptsRemaining: Int = 5
    @Published var isBusy = false

    private let functions = Functions.functions()
    private var cooldownTimer: Timer?

    enum VerificationState: Equatable {
        case enterEmail
        case codeSent(email: String)
        case verified
        case error(String)
    }

    // MARK: - Send Verification Code

    func sendCode(to email: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedEmail.contains("@") else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isBusy = true
        errorMessage = nil

        do {
            let result = try await functions.httpsCallable("sendVerificationCode").call(["email": normalizedEmail])

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool, success {
                state = .codeSent(email: normalizedEmail)
                startSendCooldown()
            } else {
                errorMessage = "Unexpected response from server."
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == FunctionsErrorDomain {
                let code = FunctionsErrorCode(rawValue: nsError.code)
                switch code {
                case .resourceExhausted:
                    errorMessage = "Too many requests. Try again in an hour."
                case .invalidArgument:
                    errorMessage = "Invalid email address."
                default:
                    errorMessage = nsError.localizedDescription
                }
            } else {
                errorMessage = "Network error. Check your connection."
            }
        }

        isBusy = false
    }

    // MARK: - Verify Code

    func verifyCode(_ code: String, email: String) async -> Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !code.isEmpty else {
            errorMessage = "Please enter the verification code."
            return false
        }

        isBusy = true
        errorMessage = nil

        do {
            let result = try await functions.httpsCallable("verifyCode").call([
                "email": normalizedEmail,
                "code": code
            ])

            if let data = result.data as? [String: Any],
               let verified = data["verified"] as? Bool, verified {
                state = .verified
                isBusy = false
                return true
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == FunctionsErrorDomain {
                let code = FunctionsErrorCode(rawValue: nsError.code)
                switch code {
                case .resourceExhausted:
                    errorMessage = "Too many failed attempts. Request a new code."
                    verifyAttemptsRemaining = 0
                case .deadlineExceeded:
                    errorMessage = "Code expired. Request a new one."
                    state = .enterEmail
                case .notFound:
                    errorMessage = "No code found. Request a new one."
                    state = .enterEmail
                case .permissionDenied:
                    verifyAttemptsRemaining -= 1
                    errorMessage = nsError.localizedDescription
                default:
                    errorMessage = nsError.localizedDescription
                }
            } else {
                errorMessage = "Network error. Check your connection."
            }
        }

        isBusy = false
        return false
    }

    // MARK: - Reset

    func reset() {
        state = .enterEmail
        errorMessage = nil
        sendCooldownRemaining = 0
        verifyAttemptsRemaining = 5
        cooldownTimer?.invalidate()
    }

    // MARK: - Cooldown

    private func startSendCooldown() {
        sendCooldownRemaining = 60
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.sendCooldownRemaining > 0 {
                    self.sendCooldownRemaining -= 1
                } else {
                    self.cooldownTimer?.invalidate()
                }
            }
        }
    }
}
