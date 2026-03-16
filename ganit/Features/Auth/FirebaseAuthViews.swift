import SwiftUI

// MARK: - Firebase Auth Root View

struct FirebaseAuthRootView: View {
    @ObservedObject var authService: FirebaseAuthService

    var body: some View {
        VStack(spacing: 24) {
            Text("Ganit")
                .font(.largeTitle.bold())
            Text("Learn. Play. Grow.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            NavigationLink("Log In") {
                FirebaseLoginView(authService: authService)
            }
            .buttonStyle(.borderedProminent)

            NavigationLink("Sign Up") {
                FirebaseSignUpView(authService: authService)
            }
            .buttonStyle(.bordered)

            Button("Continue as Guest") {
                Task { await authService.continueAsGuest() }
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Firebase Login View

struct FirebaseLoginView: View {
    @ObservedObject var authService: FirebaseAuthService
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome Back")
                .font(.title2.bold())

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            if let error = authService.authError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if authService.isLoading {
                ProgressView("Signing in...")
            } else {
                Button("Log In") {
                    Task { await authService.login(email: email, password: password) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty)
            }

            NavigationLink("Forgot Password?") {
                PasswordResetView(authService: authService)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Firebase Sign Up View

struct FirebaseSignUpView: View {
    @ObservedObject var authService: FirebaseAuthService
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedGroup: UserGroup = .child
    @State private var age = ""
    @State private var parentEmail = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Create Account")
                    .font(.title2.bold())

                TextField("Display Name", text: $username)
                    .textFieldStyle(.roundedBorder)

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif

                SecureField("Password (6+ characters)", text: $password)
                    .textFieldStyle(.roundedBorder)

                Picker("I am a...", selection: $selectedGroup) {
                    Text("Student").tag(UserGroup.child)
                    Text("Adult/Senior").tag(UserGroup.elderly)
                }
                .pickerStyle(.segmented)

                if selectedGroup == .child {
                    TextField("Age", text: $age)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif

                    TextField("Parent's email", text: $parentEmail)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                }

                if let error = authService.authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if authService.isLoading {
                    ProgressView("Creating account...")
                } else {
                    Button("Create Account") {
                        Task {
                            await authService.signUp(
                                username: username,
                                email: email,
                                password: password,
                                userGroup: selectedGroup,
                                age: Int(age),
                                parentEmail: parentEmail.isEmpty ? nil : parentEmail
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.isEmpty || email.isEmpty || password.isEmpty)
                }
            }
            .padding()
        }
    }
}

// MARK: - Password Reset View

struct PasswordResetView: View {
    @ObservedObject var authService: FirebaseAuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var sent = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Reset Password")
                .font(.title2.bold())

            Text("Enter your email and we'll send a reset link.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif

            if sent {
                Text("Reset email sent! Check your inbox.")
                    .foregroundColor(.green)
            } else {
                Button("Send Reset Link") {
                    Task {
                        if await authService.sendPasswordReset(email: email) {
                            sent = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty)
            }

            if let error = authService.authError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .navigationTitle("Reset Password")
    }
}
