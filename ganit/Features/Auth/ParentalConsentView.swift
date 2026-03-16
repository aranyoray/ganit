import SwiftUI

// MARK: - Parental Consent View

struct ParentalConsentView: View {
    @ObservedObject var authService: FirebaseAuthService
    @StateObject private var coppaService = FirebaseCOPPAService()
    let username: String

    @State private var parentEmail = ""
    @State private var verificationCode = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Parent/Guardian Verification")
                .font(.title2.bold())

            Text("We'll send a verification code to the parent's email.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            switch coppaService.state {
            case .enterEmail:
                TextField("parent@example.com", text: $parentEmail)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif

                if coppaService.isBusy {
                    ProgressView("Sending...")
                } else {
                    Button("Send Verification Code") {
                        Task { await coppaService.sendCode(to: parentEmail) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(parentEmail.isEmpty || !parentEmail.contains("@") || coppaService.sendCooldownRemaining > 0)
                }

                if coppaService.sendCooldownRemaining > 0 {
                    Text("Wait \(coppaService.sendCooldownRemaining)s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            case .codeSent(let email):
                Text("Code sent to \(email)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("123456", text: $verificationCode)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .multilineTextAlignment(.center)

                if coppaService.isBusy {
                    ProgressView("Verifying...")
                } else {
                    Button("Verify & Grant Consent") {
                        Task {
                            let success = await coppaService.verifyCode(verificationCode, email: email)
                            if success {
                                await authService.grantParentalConsent(for: username)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(verificationCode.count != 6 || coppaService.verifyAttemptsRemaining <= 0)
                }

                Button("Resend Code") {
                    coppaService.reset()
                    verificationCode = ""
                }
                .font(.caption)
                .disabled(coppaService.sendCooldownRemaining > 0)

            case .verified:
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                Text("Consent Verified!")
                    .font(.headline)
                    .foregroundColor(.green)
                Text("\(username) can now use all features.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

            case .error(let message):
                Text(message)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    coppaService.reset()
                    verificationCode = ""
                }
                .buttonStyle(.bordered)
            }

            if let error = coppaService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Parental Consent")
    }
}

// MARK: - Consent Status Banner

struct ConsentStatusBanner: View {
    let user: UserProfile?

    var body: some View {
        if let user = user, user.userGroup == .child, !user.consentGranted {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Parental consent required for full features")
                    .font(.caption)
                Spacer()
                Text("Verify")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
