import Foundation
import ARKit
import Combine

// MARK: - Eye Tracking Provider

/// Subscribes to ARSessionManager's face anchor updates and extracts gaze data.
/// Detects fixations, saccades, and gaze avoidance to publish GazeFixation events.
@MainActor
final class EyeTrackingProvider: ObservableObject, EyeTrackingProviderProtocol {

    // MARK: - Configuration

    /// Minimum duration (seconds) for a gaze on the same region to count as a fixation.
    private let fixationThreshold: TimeInterval = 0.3

    /// Maximum angular velocity (radians/sec) below which gaze is considered stable.
    private let saccadeVelocityThreshold: Float = 2.0

    /// Screen bounds used for lookAtPoint mapping.
    private let screenBounds: CGRect

    // MARK: - Signal Provider

    var isAvailable: Bool {
        ARSessionManager.shared.isFaceTrackingSupported
    }

    @Published private(set) var signalQuality: SignalQuality = .noData

    // MARK: - Publisher

    private let gazeSubject = PassthroughSubject<GazeFixation, Never>()
    var gazePublisher: AnyPublisher<GazeFixation, Never> {
        gazeSubject.eraseToAnyPublisher()
    }

    // MARK: - Gaze State

    private var currentRegion: GazeRegion = .unknown
    private var regionEntryTime: Date?
    private var previousLookAtPoint: SIMD3<Float>?
    private var previousUpdateTime: Date?
    private var isTracking = false

    /// Accumulated saccade count for the current question.
    private(set) var saccadeCount: Int = 0

    /// Accumulated time the user has been looking away from the screen.
    private(set) var gazeAvoidanceDuration: TimeInterval = 0
    private var avoidanceStartTime: Date?

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()
    private let sessionManager: ARSessionManager

    // MARK: - Init

    init(
        sessionManager: ARSessionManager = .shared,
        screenBounds: CGRect = UIScreen.main.bounds
    ) {
        self.sessionManager = sessionManager
        self.screenBounds = screenBounds
    }

    // MARK: - Lifecycle

    func start() {
        guard isAvailable else { return }

        isTracking = true
        resetState()

        sessionManager.faceAnchorSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] faceAnchor in
                self?.processFaceAnchor(faceAnchor)
            }
            .store(in: &cancellables)

        sessionManager.faceTrackingStateSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] anchor in
                self?.handleTrackingStateChange(anchor)
            }
            .store(in: &cancellables)
    }

    func stop() {
        isTracking = false
        cancellables.removeAll()
        finalizeCurrentFixation()
        resetState()
        signalQuality = .noData
    }

    /// Resets per-question counters. Call when a new question appears.
    func resetQuestionMetrics() {
        saccadeCount = 0
        gazeAvoidanceDuration = 0
        avoidanceStartTime = nil
        currentRegion = .unknown
        regionEntryTime = nil
    }

    // MARK: - Face Anchor Processing

    private func processFaceAnchor(_ faceAnchor: ARFaceAnchor) {
        guard isTracking else { return }

        let now = Date()
        let lookAtPoint = faceAnchor.lookAtPoint
        signalQuality = faceAnchor.isTracked ? .good : .lowConfidence

        guard faceAnchor.isTracked else {
            handleFaceLost(at: now)
            return
        }

        // Map lookAtPoint to screen region
        let screenPoint = mapToScreen(lookAtPoint: lookAtPoint)
        let region = classifyRegion(screenPoint: screenPoint)

        // Detect saccades
        detectSaccade(currentPoint: lookAtPoint, at: now)

        // Track gaze avoidance
        updateGazeAvoidance(region: region, at: now)

        // Track fixations
        updateFixation(region: region, at: now)

        previousLookAtPoint = lookAtPoint
        previousUpdateTime = now
    }

    // MARK: - Screen Mapping

    /// Maps the ARFaceAnchor lookAtPoint (in face-relative 3D space) to a 2D screen point.
    /// lookAtPoint is relative to the face anchor: x is right, y is up, z is out of the face.
    private func mapToScreen(lookAtPoint: SIMD3<Float>) -> CGPoint {
        // lookAtPoint.x: horizontal deviation (negative = looking left, positive = looking right)
        // lookAtPoint.y: vertical deviation (negative = looking down, positive = looking up)
        // We normalize to screen coordinates assuming typical phone-to-face distance.

        let horizontalRange: Float = 0.05  // ~2.8 degrees each side
        let verticalRange: Float = 0.08    // ~4.6 degrees each side

        let normalizedX = CGFloat((lookAtPoint.x / horizontalRange + 1) / 2)
        let normalizedY = CGFloat(1.0 - (lookAtPoint.y / verticalRange + 1) / 2)

        let screenX = normalizedX * screenBounds.width
        let screenY = normalizedY * screenBounds.height

        return CGPoint(
            x: max(0, min(screenBounds.width, screenX)),
            y: max(0, min(screenBounds.height, screenY))
        )
    }

    // MARK: - Region Classification

    /// Classifies a screen point into a GazeRegion based on typical quiz layout zones.
    /// Layout assumption: question text in top ~30%, four options stacked in remaining ~70%.
    private func classifyRegion(screenPoint: CGPoint) -> GazeRegion {
        let relativeY = screenPoint.y / screenBounds.height
        let relativeX = screenPoint.x / screenBounds.width

        // Off-screen gaze
        guard (0...1).contains(relativeX) && (0...1).contains(relativeY) else {
            return .elsewhere
        }

        if relativeY < 0.30 {
            return .questionText
        }

        // Options zone: 30% to 95% of screen height, split into 4 equal bands
        let optionZoneStart: CGFloat = 0.30
        let optionZoneEnd: CGFloat = 0.95
        let optionHeight = (optionZoneEnd - optionZoneStart) / 4.0

        if relativeY < optionZoneStart + optionHeight {
            return .optionA
        } else if relativeY < optionZoneStart + optionHeight * 2 {
            return .optionB
        } else if relativeY < optionZoneStart + optionHeight * 3 {
            return .optionC
        } else if relativeY < optionZoneEnd {
            return .optionD
        }

        return .elsewhere
    }

    // MARK: - Fixation Detection

    private func updateFixation(region: GazeRegion, at time: Date) {
        if region == currentRegion {
            // Still looking at the same region; check if we crossed the fixation threshold
            if let entryTime = regionEntryTime {
                let duration = time.timeIntervalSince(entryTime)
                if duration >= fixationThreshold {
                    // Emit fixation event
                    let fixation = GazeFixation(
                        region: region,
                        duration: duration,
                        timestamp: entryTime
                    )
                    gazeSubject.send(fixation)
                    // Reset entry time so we emit subsequent fixation windows
                    regionEntryTime = time
                }
            }
        } else {
            // Region changed: finalize previous fixation if any
            finalizeCurrentFixation()
            currentRegion = region
            regionEntryTime = time
        }
    }

    /// Emits a final fixation event for the current region before switching.
    private func finalizeCurrentFixation() {
        guard let entryTime = regionEntryTime else { return }
        let duration = Date().timeIntervalSince(entryTime)
        if duration >= fixationThreshold {
            let fixation = GazeFixation(
                region: currentRegion,
                duration: duration,
                timestamp: entryTime
            )
            gazeSubject.send(fixation)
        }
    }

    // MARK: - Saccade Detection

    private func detectSaccade(currentPoint: SIMD3<Float>, at time: Date) {
        guard let prevPoint = previousLookAtPoint,
              let prevTime = previousUpdateTime else { return }

        let dt = Float(time.timeIntervalSince(prevTime))
        guard dt > 0 else { return }

        let delta = currentPoint - prevPoint
        let angularVelocity = length(delta) / dt

        if angularVelocity > saccadeVelocityThreshold {
            saccadeCount += 1
        }
    }

    // MARK: - Gaze Avoidance

    private func updateGazeAvoidance(region: GazeRegion, at time: Date) {
        if region == .elsewhere {
            if avoidanceStartTime == nil {
                avoidanceStartTime = time
            }
        } else {
            if let start = avoidanceStartTime {
                gazeAvoidanceDuration += time.timeIntervalSince(start)
                avoidanceStartTime = nil
            }
        }
    }

    // MARK: - Face Lost Handling

    private func handleFaceLost(at time: Date) {
        signalQuality = .noData
        finalizeCurrentFixation()

        // Treat face lost as avoidance
        if avoidanceStartTime == nil {
            avoidanceStartTime = time
        }

        currentRegion = .unknown
        regionEntryTime = nil
        previousLookAtPoint = nil
        previousUpdateTime = nil
    }

    private func handleTrackingStateChange(_ anchor: ARFaceAnchor?) {
        if anchor == nil {
            handleFaceLost(at: Date())
        } else {
            signalQuality = .good
        }
    }

    // MARK: - State Reset

    private func resetState() {
        currentRegion = .unknown
        regionEntryTime = nil
        previousLookAtPoint = nil
        previousUpdateTime = nil
        saccadeCount = 0
        gazeAvoidanceDuration = 0
        avoidanceStartTime = nil
        signalQuality = .noData
    }
}
