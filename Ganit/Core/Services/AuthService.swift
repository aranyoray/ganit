import Foundation
import Combine

// MARK: - Auth Service

/// Handles authentication, user creation, and COPPA consent.
/// Extracted from ganit_base/UserLogIn.swift with user group support.
@MainActor
class AuthService: ObservableObject {

    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false
    @Published var authError: String?

    private let storage: StorageProvider

    init(storage: StorageProvider = EncryptedStorage.shared) {
        self.storage = storage
    }

    // MARK: - Sign Up

    func signUp(username: String, password: String, userGroup: UserGroup, age: Int?, parentEmail: String?) -> Bool {
        guard !username.isEmpty, !password.isEmpty else {
            authError = "Username and password are required."
            return false
        }

        // Check if user already exists
        if storage.loadPassword(username: username) != nil {
            authError = "Username is already taken."
            return false
        }

        // COPPA: children under 13 need parental consent
        if userGroup == .child {
            if let age = age, age < 13, (parentEmail == nil || parentEmail!.isEmpty) {
                authError = "Parent email is required for users under 13."
                return false
            }
        }

        storage.savePassword(username: username, password: password)

        let profile = UserProfile(
            username: username,
            userGroup: userGroup,
            age: age,
            parentEmail: parentEmail,
            consentGranted: userGroup == .elderly  // Elderly self-consent
        )

        storage.saveCodable("profile", value: profile, user: username)

        currentUser = profile
        isAuthenticated = true
        authError = nil
        return true
    }

    // MARK: - Login

    func login(username: String, password: String) -> Bool {
        guard !username.isEmpty else {
            authError = "Please enter your username."
            return false
        }

        guard let storedPassword = storage.loadPassword(username: username),
              password == storedPassword else {
            authError = "Username not found or password is incorrect."
            return false
        }

        // Load profile
        if let profile: UserProfile = storage.readCodable("profile", as: UserProfile.self, user: username) {
            currentUser = profile
        } else {
            // Legacy user without profile — default to child
            currentUser = UserProfile(username: username, userGroup: .child)
        }

        isAuthenticated = true
        authError = nil
        return true
    }

    // MARK: - Guest Mode

    func continueAsGuest() {
        currentUser = UserProfile(
            username: "guest_\(UUID().uuidString.prefix(8))",
            userGroup: .child,
            consentGranted: false
        )
        isAuthenticated = true
        authError = nil
    }

    // MARK: - Logout

    func logout() {
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Account Deletion

    func deleteAccount(username: String) {
        // Clear all encrypted storage data for this user
        EncryptedStorage.shared.deleteAllData(for: username)

        // Remove password from Keychain
        EncryptedStorage.shared.deletePassword(username: username)

        // Reset app state
        currentUser = nil
        isAuthenticated = false
        authError = nil
    }

    // MARK: - COPPA Consent

    func grantParentalConsent(for username: String) {
        guard var profile = currentUser, profile.username == username else { return }
        profile.consentGranted = true
        currentUser = profile
        storage.saveCodable("profile", value: profile, user: username)
    }

    // MARK: - Reset Progress

    func resetProgress(username: String, password: String, progressState: ProgressState) -> Bool {
        guard login(username: username, password: password) else { return false }
        progressState.resetAll()
        return true
    }
}
