import SwiftUI
#if os(iOS)
import AVFoundation
#endif

// MARK: - Ganit App Entry Point

@main
struct GanitApp: App {
    // Services
    @StateObject private var authService = AuthService()
    @StateObject private var progressState = ProgressState(storage: EncryptedStorage.shared)
    @StateObject private var questionService = AIQuestionService()
    @StateObject private var touchProvider = TouchPatternProvider()
    @StateObject private var signalAggregator: SignalAggregator

    init() {
        let touch = TouchPatternProvider()
        _touchProvider = StateObject(wrappedValue: touch)
        _signalAggregator = StateObject(wrappedValue: SignalAggregator(touchProvider: touch))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    HomeScreen(
                        progressState: progressState,
                        questionService: questionService,
                        signalAggregator: signalAggregator,
                        touchProvider: touchProvider,
                        userGroup: authService.currentUser?.userGroup ?? .child,
                        authService: authService
                    )
                    .onAppear {
                        if let user = authService.currentUser {
                            progressState.setUser(user.username)

                            // Configure V2 signal providers on supported devices
                            #if os(iOS)
                            setupSignalProviders()
                            #endif
                        }
                    }
                } else {
                    NavigationStack {
                        AuthRootView(authService: authService)
                    }
                }
            }
        }
    }

    #if os(iOS)
    private func setupSignalProviders() {
        // COPPA: Don't start signal providers for children without consent
        if let user = authService.currentUser,
           user.userGroup == .child && !user.consentGranted {
            return
        }

        // Check camera permission before starting AR-dependent providers
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard cameraStatus == .authorized || cameraStatus == .notDetermined else {
            // Camera denied — skip AR setup, quiz still works without it
            return
        }

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
