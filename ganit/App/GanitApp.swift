import SwiftUI
import FirebaseCore

// MARK: - Firebase App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

// MARK: - Ganit App Entry Point

@main
struct GanitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Services — all created in init() for consistent wiring
    @StateObject private var firebaseAuth: FirebaseAuthService
    @StateObject private var progressState: ProgressState
    @StateObject private var questionService: AIQuestionService
    @StateObject private var touchProvider: TouchPatternProvider
    @StateObject private var signalAggregator: SignalAggregator

    init() {
        let storage = EncryptedStorage.shared
        let touch = TouchPatternProvider()

        // Always sync Gemini API key from Secrets.swift
        storage.saveAPIKey(Secrets.geminiAPIKey)

        _firebaseAuth = StateObject(wrappedValue: FirebaseAuthService())
        _progressState = StateObject(wrappedValue: ProgressState(storage: storage))
        _questionService = StateObject(wrappedValue: AIQuestionService(storage: storage))
        _touchProvider = StateObject(wrappedValue: touch)
        _signalAggregator = StateObject(wrappedValue: SignalAggregator(touchProvider: touch))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if firebaseAuth.isAuthenticated {
                    HomeScreen(
                        progressState: progressState,
                        questionService: questionService,
                        signalAggregator: signalAggregator,
                        touchProvider: touchProvider,
                        userGroup: firebaseAuth.currentUser?.userGroup ?? .child,
                        firebaseAuth: firebaseAuth
                    )
                    .onAppear {
                        if let user = firebaseAuth.currentUser {
                            progressState.setUser(user.username)
                            #if os(iOS)
                            setupSignalProviders()
                            #endif
                        }
                    }
                } else {
                    NavigationStack {
                        FirebaseAuthRootView(authService: firebaseAuth)
                    }
                }
            }
        }
    }

    #if os(iOS)
    private func setupSignalProviders() {
        let arManager = ARSessionManager.shared
        if arManager.isFaceTrackingSupported {
            let eyeProvider = EyeTrackingProvider(sessionManager: arManager)
            let faceProvider = FacialAnalysisProvider(sessionManager: arManager)
            signalAggregator.configureEyeTracking(eyeProvider)
            signalAggregator.configureFacialAnalysis(faceProvider)
            eyeProvider.start()
            faceProvider.start()
        }
    }
    #endif
}
