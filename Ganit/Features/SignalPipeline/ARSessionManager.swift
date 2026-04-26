import Foundation
import ARKit
import Combine

// MARK: - AR Session Mode

enum ARSessionMode {
    case faceTrackingOnly    // Non-AR quiz mode (TrueDepth camera only)
    case worldWithFace       // AR mode (world tracking + user face tracking)
}

// MARK: - AR Session Manager

/// Shared singleton that owns the ARSession and broadcasts anchor updates via Combine.
/// All face-dependent providers (eye tracking, facial analysis) subscribe to this
/// rather than owning their own sessions.
@MainActor
final class ARSessionManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = ARSessionManager()

    // MARK: - Publishers

    /// Emits every time a face anchor is updated (approximately 60 Hz on supported devices).
    let faceAnchorSubject = PassthroughSubject<ARFaceAnchor, Never>()

    /// Emits when face tracking is lost (nil) or recovered (non-nil).
    let faceTrackingStateSubject = PassthroughSubject<ARFaceAnchor?, Never>()

    /// Emits detected plane anchors for AR world scenes.
    let planeAnchorSubject = PassthroughSubject<ARPlaneAnchor, Never>()

    /// Emits session interruption events.
    let sessionInterruptedSubject = PassthroughSubject<Bool, Never>()

    // MARK: - State

    @Published private(set) var isRunning = false
    @Published private(set) var currentMode: ARSessionMode?
    @Published private(set) var isFaceTracked = false
    @Published var sessionError: String?

    let session = ARSession()

    // MARK: - Device Capabilities

    /// Whether the device has a TrueDepth camera and supports face tracking.
    var isFaceTrackingSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    /// Whether the device supports world tracking with simultaneous face tracking.
    var isWorldFaceTrackingSupported: Bool {
        guard ARWorldTrackingConfiguration.isSupported else { return false }
        return ARWorldTrackingConfiguration.supportsUserFaceTracking
    }

    // MARK: - Init

    private override init() {
        super.init()
        session.delegate = self
    }

    // MARK: - Lifecycle

    /// Starts the AR session in the specified mode.
    /// - Parameter mode: The tracking configuration to use.
    func start(mode: ARSessionMode = .faceTrackingOnly) {
        sessionError = nil
        guard let configuration = makeConfiguration(for: mode) else {
            sessionError = "AR configuration not supported on this device."
            return
        }

        currentMode = mode
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
    }

    /// Stops the AR session and resets state.
    func stop() {
        session.pause()
        isRunning = false
        isFaceTracked = false
        currentMode = nil
        faceTrackingStateSubject.send(nil)
    }

    /// Reconfigures the session to a new mode without full teardown.
    /// Preserves existing anchors when possible.
    func reconfigure(to mode: ARSessionMode) {
        guard let configuration = makeConfiguration(for: mode) else {
            return
        }

        currentMode = mode
        session.run(configuration, options: [.resetTracking])
    }

    // MARK: - Configuration Factory

    private func makeConfiguration(for mode: ARSessionMode) -> ARConfiguration? {
        switch mode {
        case .faceTrackingOnly:
            guard isFaceTrackingSupported else { return nil }
            let config = ARFaceTrackingConfiguration()
            config.isLightEstimationEnabled = false
            if #available(iOS 16.0, *) {
                config.maximumNumberOfTrackedFaces = 1
            }
            return config

        case .worldWithFace:
            guard ARWorldTrackingConfiguration.isSupported else { return nil }
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal, .vertical]
            config.isLightEstimationEnabled = true
            if isWorldFaceTrackingSupported {
                config.userFaceTrackingEnabled = true
            }
            return config
        }
    }
}

// MARK: - ARSessionDelegate

extension ARSessionManager: ARSessionDelegate {

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let faceAnchors = anchors.compactMap { $0 as? ARFaceAnchor }
        let planeAnchors = anchors.compactMap { $0 as? ARPlaneAnchor }

        Task { @MainActor in
            for faceAnchor in faceAnchors {
                faceAnchorSubject.send(faceAnchor)

                if !isFaceTracked {
                    isFaceTracked = true
                    faceTrackingStateSubject.send(faceAnchor)
                }
            }

            for planeAnchor in planeAnchors {
                planeAnchorSubject.send(planeAnchor)
            }
        }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let removedFaces = anchors.contains { $0 is ARFaceAnchor }

        if removedFaces {
            Task { @MainActor in
                isFaceTracked = false
                faceTrackingStateSubject.send(nil)
            }
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            sessionInterruptedSubject.send(true)
            isFaceTracked = false
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            sessionInterruptedSubject.send(false)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            isRunning = false
            isFaceTracked = false
            sessionError = error.localizedDescription
            faceTrackingStateSubject.send(nil)
        }
    }
}
