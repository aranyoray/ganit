import SwiftUI
import Combine
import LocalAuthentication

// MARK: - Privacy Settings View Model

@MainActor
class PrivacySettingsViewModel: ObservableObject {
    @Published var consent: BiometricConsent
    @Published var sessionCount: Int = 0
    @Published var parentModeUnlocked: Bool = false

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
        let index = EncryptedStorage.shared.loadSessionIndex(user: username)
        self.sessionCount = index.count
    }

    func saveConsent() {
        storage.saveCodable(BiometricConsent.storageKey, value: consent, user: username)
    }

    func authenticateParent() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // No biometrics — fall back to passcode
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock parent settings") { success, _ in
                Task { @MainActor in
                    self.parentModeUnlocked = success
                }
            }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock parent settings") { success, _ in
            Task { @MainActor in
                self.parentModeUnlocked = success
            }
        }
    }

    func deleteAllData() {
        let sessionIds = EncryptedStorage.shared.loadSessionIndex(user: username)
        for sessionId in sessionIds {
            storage.save("session_\(sessionId.uuidString)", value: "", user: username)
        }
        EncryptedStorage.shared.saveSessionIndex([], user: username)
        storage.save("screeningResults", value: "", user: username)
        storage.save("profile", value: "", user: username)
        storage.save(BiometricConsent.storageKey, value: "", user: username)
        let progressKeys = [
            "score", "AdditionLevel", "SubtractionLevel", "MultiplicationLevel",
            "DivisionLevel", "progress", "XPRequirements", "color", "Coins",
            "shows", "vipshows", "powerUpPointLevel", "onWhichLevel", "characterList"
        ]
        for key in progressKeys {
            storage.save(key, value: "", user: username)
        }
        sessionCount = 0
        consent = BiometricConsent()
    }

    func purgeExpiredSessions() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let sessionIds = EncryptedStorage.shared.loadSessionIndex(user: username)
        var idsToKeep: [UUID] = []
        for sessionId in sessionIds {
            if let session = EncryptedStorage.shared.loadSession(sessionId, user: username) {
                if session.startedAt < cutoff {
                    storage.save("session_\(sessionId.uuidString)", value: "", user: username)
                } else {
                    idsToKeep.append(sessionId)
                }
            }
        }
        if idsToKeep.count != sessionIds.count {
            EncryptedStorage.shared.saveSessionIndex(idsToKeep, user: username)
            sessionCount = idsToKeep.count
        }
    }
}

// MARK: - Settings View

struct PrivacySettingsView: View {
    @ObservedObject var viewModel: PrivacySettingsViewModel
    @State private var showDeleteConfirmation = false
    @State private var dataDeleted = false

    var body: some View {
        List {
            // Learning Signals
            Section("Learning Signals") {
                Toggle("Eye Tracking", isOn: $viewModel.consent.eyeTrackingEnabled)
                Toggle("Face Expressions", isOn: $viewModel.consent.facialAnalysisEnabled)
                Toggle("Touch Patterns", isOn: $viewModel.consent.touchTrackingEnabled)
                Toggle("Voice Analysis", isOn: $viewModel.consent.voiceTrackingEnabled)
            }
            .onChange(of: viewModel.consent.eyeTrackingEnabled) { viewModel.saveConsent() }
            .onChange(of: viewModel.consent.facialAnalysisEnabled) { viewModel.saveConsent() }
            .onChange(of: viewModel.consent.touchTrackingEnabled) { viewModel.saveConsent() }
            .onChange(of: viewModel.consent.voiceTrackingEnabled) { viewModel.saveConsent() }

            // Parent Settings — locked behind Face ID
            Section {
                if viewModel.parentModeUnlocked {
                    NavigationLink(value: AppDestination.parentDashboard) {
                        Label("Dashboard & Reports", systemImage: "chart.bar")
                    }
                    NavigationLink(value: AppDestination.learningStory) {
                        Label("Learning Story", systemImage: "book")
                    }

                    if dataDeleted {
                        Text("All data has been deleted.")
                            .foregroundColor(.green)
                    } else {
                        Button("Delete All Data", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                        .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                            Button("Cancel", role: .cancel) {}
                            Button("Delete Everything", role: .destructive) {
                                viewModel.deleteAllData()
                                dataDeleted = true
                            }
                        } message: {
                            Text("This will permanently delete all progress, sessions, and personal data. This cannot be undone.")
                        }
                    }

                    Button("Lock Parent Settings") {
                        viewModel.parentModeUnlocked = false
                    }
                    .foregroundColor(.secondary)
                } else {
                    Button {
                        viewModel.authenticateParent()
                    } label: {
                        Label("Unlock with Face ID", systemImage: "faceid")
                    }
                }
            } header: {
                Text("Parent Settings")
            } footer: {
                if !viewModel.parentModeUnlocked {
                    Text("Dashboard, reports, and data controls are protected with Face ID.")
                }
            }
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            viewModel.purgeExpiredSessions()
        }
    }
}
