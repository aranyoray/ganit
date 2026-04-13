import SwiftUI

// MARK: - Login View

struct LoginView: View {
    @ObservedObject var authService: AuthService
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome Back")
                .font(.title2.bold())

            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            if let error = authService.authError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button("Log In") {
                _ = authService.login(username: username, password: password)
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || password.isEmpty)
        }
        .padding()
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @ObservedObject var authService: AuthService
    @State private var username = ""
    @State private var password = ""
    @State private var selectedGroup: UserGroup = .child
    @State private var age = ""
    @State private var parentEmail = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Create Account")
                    .font(.title2.bold())

                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                // User group picker
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

                    if let ageInt = Int(age), ageInt < 13 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Parent/Guardian Consent Required")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("For users under 13, we need a parent or guardian's email to verify consent.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Parent's email", text: $parentEmail)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                #endif
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }
                }

                if let error = authService.authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button("Create Account") {
                    let ageInt = Int(age)
                    _ = authService.signUp(
                        username: username,
                        password: password,
                        userGroup: selectedGroup,
                        age: ageInt,
                        parentEmail: parentEmail.isEmpty ? nil : parentEmail
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || password.isEmpty)
            }
            .padding()
        }
    }
}

// MARK: - Auth Root View

struct AuthRootView: View {
    @ObservedObject var authService: AuthService

    var body: some View {
        VStack(spacing: 24) {
            Text("Ganit")
                .font(.largeTitle.bold())
            Text("Learn. Play. Grow.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            NavigationLink("Log In") {
                LoginView(authService: authService)
            }
            .buttonStyle(.borderedProminent)

            NavigationLink("Sign Up") {
                SignUpView(authService: authService)
            }
            .buttonStyle(.bordered)

            Button("Continue as Guest") {
                authService.continueAsGuest()
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
}
