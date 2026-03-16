import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firebase Auth Service

/// Replaces Keychain-based AuthService with Firebase Auth + Firestore.
///
/// ```
/// SignUp → Firebase Auth createUser → Firestore /users/{uid} → authenticated
/// Login  → Firebase Auth signIn    → Firestore /users/{uid} → authenticated
/// Guest  → Firebase Auth anonymous → no Firestore doc       → authenticated
/// COPPA  → Cloud Function email    → verifyCode             → consent granted
/// ```
@MainActor
class FirebaseAuthService: ObservableObject {

    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false
    @Published var authError: String?
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        // Listen for auth state changes (handles app restart with existing session)
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                if let firebaseUser {
                    await self?.loadUserProfile(uid: firebaseUser.uid)
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Sign Up

    @discardableResult
    func signUp(
        username: String,
        email: String,
        password: String,
        userGroup: UserGroup,
        age: Int?,
        parentEmail: String?
    ) async -> Bool {
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            authError = "All fields are required."
            return false
        }

        guard password.count >= 6 else {
            authError = "Password must be at least 6 characters."
            return false
        }

        if userGroup == .child {
            if let age = age, age < 13, (parentEmail == nil || parentEmail!.isEmpty) {
                authError = "Parent email is required for users under 13."
                return false
            }
        }

        isLoading = true
        authError = nil

        do {
            // Create Firebase Auth user
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid

            // Create user profile in Firestore
            let profile = UserProfile(
                id: UUID(),
                username: username,
                userGroup: userGroup,
                age: age,
                parentEmail: parentEmail,
                consentGranted: userGroup == .elderly
            )

            try await db.collection("users").document(uid).setData([
                "id": profile.id.uuidString,
                "username": username,
                "userGroup": userGroup.rawValue,
                "age": age as Any,
                "parentEmail": parentEmail as Any,
                "consentGranted": profile.consentGranted,
                "createdAt": FieldValue.serverTimestamp()
            ])

            currentUser = profile
            isAuthenticated = true
            isLoading = false
            return true

        } catch let error as NSError {
            isLoading = false
            if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                authError = "Email is already registered."
            } else if error.code == AuthErrorCode.weakPassword.rawValue {
                authError = "Password is too weak."
            } else if error.code == AuthErrorCode.invalidEmail.rawValue {
                authError = "Invalid email address."
            } else {
                authError = error.localizedDescription
            }
            return false
        }
    }

    // MARK: - Login

    @discardableResult
    func login(email: String, password: String) async -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            authError = "Email and password are required."
            return false
        }

        isLoading = true
        authError = nil

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await loadUserProfile(uid: result.user.uid)
            isLoading = false
            return true
        } catch let error as NSError {
            isLoading = false
            if error.code == AuthErrorCode.wrongPassword.rawValue ||
               error.code == AuthErrorCode.userNotFound.rawValue {
                authError = "Invalid email or password."
            } else if error.code == AuthErrorCode.tooManyRequests.rawValue {
                authError = "Too many attempts. Try again later."
            } else {
                authError = error.localizedDescription
            }
            return false
        }
    }

    // MARK: - Guest Mode

    func continueAsGuest() async {
        isLoading = true
        do {
            try await Auth.auth().signInAnonymously()
            currentUser = UserProfile(
                username: "guest_\(UUID().uuidString.prefix(8))",
                userGroup: .child,
                consentGranted: false
            )
            isAuthenticated = true
        } catch {
            authError = "Could not start guest session."
        }
        isLoading = false
    }

    // MARK: - Logout

    func logout() {
        do {
            try Auth.auth().signOut()
        } catch {
            authError = "Logout failed."
        }
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async -> Bool {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return true
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    // MARK: - COPPA Consent

    @discardableResult
    func grantParentalConsent(for username: String) async -> Bool {
        guard var profile = currentUser, profile.username == username else { return false }
        guard let uid = Auth.auth().currentUser?.uid else { return false }

        profile.consentGranted = true
        currentUser = profile

        do {
            try await db.collection("users").document(uid).updateData([
                "consentGranted": true,
                "consentGrantedAt": FieldValue.serverTimestamp()
            ])
            return true
        } catch {
            authError = "Failed to save consent."
            return false
        }
    }

    // MARK: - Load Profile from Firestore

    private func loadUserProfile(uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            guard let data = doc.data() else {
                // Anonymous user without profile
                currentUser = UserProfile(
                    username: "guest_\(uid.prefix(8))",
                    userGroup: .child,
                    consentGranted: false
                )
                isAuthenticated = true
                return
            }

            currentUser = UserProfile(
                id: UUID(uuidString: data["id"] as? String ?? "") ?? UUID(),
                username: data["username"] as? String ?? "user",
                userGroup: UserGroup(rawValue: data["userGroup"] as? String ?? "child") ?? .child,
                age: data["age"] as? Int,
                parentEmail: data["parentEmail"] as? String,
                consentGranted: data["consentGranted"] as? Bool ?? false
            )
            isAuthenticated = true
        } catch {
            authError = "Failed to load profile."
        }
    }

    // MARK: - Delete Account (COPPA)

    func deleteAccount() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }

        do {
            // Delete Firestore subcollections
            for sub in ["sessions", "screeningResults"] {
                let snapshot = try await db.collection("users").document(uid).collection(sub).getDocuments()
                for doc in snapshot.documents {
                    try await doc.reference.delete()
                }
            }

            // Delete user document
            try await db.collection("users").document(uid).delete()

            // Delete Firebase Auth user
            try await Auth.auth().currentUser?.delete()

            currentUser = nil
            isAuthenticated = false
            return true
        } catch {
            authError = "Failed to delete account: \(error.localizedDescription)"
            return false
        }
    }
}
