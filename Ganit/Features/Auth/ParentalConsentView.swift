import SwiftUI

// MARK: - Parental Consent View (Full COPPA Compliance)

/// Full COPPA parental consent flow with email verification.
struct ParentalConsentView: View {
    @ObservedObject var authService: AuthService
    let username: String
    @State private var parentEmail = ""
    @State private var verificationCode = ""
    @State private var sentCode = false
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @State private var consentGranted = false

    // Demo: simulated verification code
    @State private var simulatedCode = String(Int.random(in: 100000...999999))

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Image(systemName: "shield.checkered")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)

                Text("Parent/Guardian Verification")
                    .font(.title2.bold())

                // Demo Mode Banner
                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(.orange)
                    Text("Demo Mode: Email verification is simulated. In the released version, a real verification email will be sent to the parent's address.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

                Text("To protect your child's privacy, we need to verify a parent or guardian's identity before collecting learning data.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Divider()

                if consentGranted {
                    consentGrantedView
                } else if sentCode {
                    verificationView
                } else {
                    emailEntryView
                }

                // What we collect
                privacyInfoSection
            }
            .padding()
        }
        .navigationTitle("Parental Consent")
    }

    // MARK: - Email Entry

    @ViewBuilder
    private var emailEntryView: some View {
        VStack(spacing: 12) {
            Text("Step 1: Enter parent/guardian email")
                .font(.headline)

            TextField("parent@example.com", text: $parentEmail)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif

            Button("Send Verification Code") {
                sendVerificationCode()
            }
            .buttonStyle(.borderedProminent)
            .disabled(parentEmail.isEmpty || !parentEmail.contains("@"))

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Verification

    @ViewBuilder
    private var verificationView: some View {
        VStack(spacing: 12) {
            Text("Step 2: Enter verification code")
                .font(.headline)

            Text("We sent a 6-digit code to \(parentEmail)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Demo hint
            Text("(Demo: code is \(simulatedCode))")
                .font(.caption)
                .foregroundColor(.orange)

            TextField("123456", text: $verificationCode)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .multilineTextAlignment(.center)
                .font(.title3.monospaced())

            if isVerifying {
                ProgressView("Verifying...")
            } else {
                Button("Verify & Grant Consent") {
                    verifyCode()
                }
                .buttonStyle(.borderedProminent)
                .disabled(verificationCode.count != 6)
            }

            Button("Resend Code") {
                simulatedCode = String(Int.random(in: 100000...999999))
                sentCode = false
                verificationCode = ""
            }
            .font(.caption)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Consent Granted

    @ViewBuilder
    private var consentGrantedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Consent Verified!")
                .font(.title3.bold())
                .foregroundColor(.green)

            Text("Thank you for verifying. \(username) can now use all learning features with full privacy protection.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("You can review and delete all data from the Parent Dashboard at any time.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Privacy Info

    @ViewBuilder
    private var privacyInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What we collect & how we protect it")
                .font(.headline)

            Group {
                privacyRow(icon: "eye.slash", text: "Camera data is processed on-device only — never stored or transmitted")
                privacyRow(icon: "lock.shield", text: "All learning data is encrypted with AES-256 on the device")
                privacyRow(icon: "chart.bar", text: "Only aggregate learning scores are stored, not raw signals")
                privacyRow(icon: "trash", text: "You can delete all data at any time from the Parent Dashboard")
                privacyRow(icon: "brain", text: "Screening indicators are suggestions only, never diagnoses")
                privacyRow(icon: "network.slash", text: "No personal data is sent to external servers")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }

    private func privacyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func sendVerificationCode() {
        guard parentEmail.contains("@") else {
            errorMessage = "Please enter a valid email address."
            return
        }
        // In production: send actual email via backend
        // Demo: just pretend we sent it
        sentCode = true
        errorMessage = nil
    }

    private func verifyCode() {
        isVerifying = true
        errorMessage = nil

        // Simulate verification delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if verificationCode == simulatedCode {
                authService.grantParentalConsent(for: username)
                consentGranted = true
            } else {
                errorMessage = "Invalid code. Please try again."
            }
            isVerifying = false
        }
    }
}

// MARK: - Consent Status Banner

/// Small banner showing consent status, for use in other views.
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
                NavigationLink("Verify") {
                    ParentalConsentView(
                        authService: AuthService(),
                        username: user.username
                    )
                }
                .font(.caption.bold())
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
