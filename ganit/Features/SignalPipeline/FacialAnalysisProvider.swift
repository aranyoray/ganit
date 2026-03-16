import Foundation
import ARKit
import Combine

// MARK: - Facial Analysis Provider

/// Subscribes to ARSessionManager's face anchor updates and classifies facial expressions
/// using ARFaceAnchor blend shape values. Publishes ExpressionSample events.
@MainActor
final class FacialAnalysisProvider: ObservableObject, FacialAnalysisProviderProtocol {

    // MARK: - Configuration

    /// Minimum confidence threshold to emit an expression sample.
    private let confidenceThreshold: Float = 0.3

    /// How often (in seconds) to emit expression samples. Throttles the 60 Hz face updates.
    private let sampleInterval: TimeInterval = 0.25

    // MARK: - Signal Provider

    var isAvailable: Bool {
        ARSessionManager.shared.isFaceTrackingSupported
    }

    @Published private(set) var signalQuality: SignalQuality = .noData

    // MARK: - Publisher

    private let expressionSubject = PassthroughSubject<ExpressionSample, Never>()
    var expressionPublisher: AnyPublisher<ExpressionSample, Never> {
        expressionSubject.eraseToAnyPublisher()
    }

    // MARK: - State

    private var lastSampleTime: Date?
    private var isTracking = false

    /// Rolling window of recent expressions for timeline tracking.
    private(set) var expressionTimeline: [ExpressionSample] = []
    private let maxTimelineLength = 120  // ~30 seconds at 4 Hz

    /// Exponential moving average of blend shape values for smoothing.
    private var smoothedBlendShapes: [ARFaceAnchor.BlendShapeLocation: Float] = [:]
    private let smoothingFactor: Float = 0.3  // Higher = more responsive, lower = smoother

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()
    private let sessionManager: ARSessionManager

    // MARK: - Init

    init(sessionManager: ARSessionManager) {
        self.sessionManager = sessionManager
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
        resetState()
        signalQuality = .noData
    }

    /// Resets the expression timeline. Call when a new question appears.
    func resetQuestionMetrics() {
        expressionTimeline.removeAll()
        smoothedBlendShapes.removeAll()
        lastSampleTime = nil
    }

    // MARK: - Face Anchor Processing

    private func processFaceAnchor(_ faceAnchor: ARFaceAnchor) {
        guard isTracking, faceAnchor.isTracked else {
            if !faceAnchor.isTracked {
                signalQuality = .noData
            }
            return
        }

        signalQuality = .good

        // Throttle to sampleInterval
        let now = Date()
        if let lastTime = lastSampleTime, now.timeIntervalSince(lastTime) < sampleInterval {
            // Still update smoothed values even when not emitting
            updateSmoothedBlendShapes(faceAnchor.blendShapes)
            return
        }

        updateSmoothedBlendShapes(faceAnchor.blendShapes)
        lastSampleTime = now

        // Classify expression
        let (category, confidence) = classifyExpression()

        guard confidence >= confidenceThreshold else {
            let sample = ExpressionSample(
                timestamp: now,
                category: .ambiguous,
                confidence: confidence
            )
            appendToTimeline(sample)
            expressionSubject.send(sample)
            return
        }

        let sample = ExpressionSample(
            timestamp: now,
            category: category,
            confidence: confidence
        )

        appendToTimeline(sample)
        expressionSubject.send(sample)
    }

    // MARK: - Blend Shape Smoothing

    private func updateSmoothedBlendShapes(_ blendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]) {
        for (location, value) in blendShapes {
            let raw = value.floatValue
            if let existing = smoothedBlendShapes[location] {
                smoothedBlendShapes[location] = existing + smoothingFactor * (raw - existing)
            } else {
                smoothedBlendShapes[location] = raw
            }
        }
    }

    // MARK: - Expression Classification

    /// Classifies the current smoothed blend shapes into an ExpressionCategory.
    /// Returns the category and a confidence score (0-1).
    private func classifyExpression() -> (ExpressionCategory, Float) {
        // Extract key blend shape groups
        let smileScore = blendShapeAverage([.mouthSmileLeft, .mouthSmileRight])
        let frownScore = blendShapeAverage([.mouthFrownLeft, .mouthFrownRight])
        let browDownScore = blendShapeAverage([.browDownLeft, .browDownRight])
        let browInnerUpScore = blendShape(.browInnerUp)
        let browOuterUpScore = blendShapeAverage([.browOuterUpLeft, .browOuterUpRight])
        let squintScore = blendShapeAverage([.eyeSquintLeft, .eyeSquintRight])
        let eyeWideScore = blendShapeAverage([.eyeWideLeft, .eyeWideRight])
        let jawOpenScore = blendShape(.jawOpen)
        let mouthPuckerScore = blendShape(.mouthPucker)
        let cheekPuffScore = blendShape(.cheekPuff)

        // Overall facial movement magnitude (used for boredom detection)
        let overallMovement = calculateOverallMovement()

        // Score each category
        var scores: [(ExpressionCategory, Float)] = []

        // Engaged: smile, raised brows, open expression
        let engagedScore = smileScore * 0.4 + browOuterUpScore * 0.2
            + (1.0 - frownScore) * 0.2 + eyeWideScore * 0.2
        scores.append((.engaged, engagedScore))

        // Confused: squint, furrowed brow, sometimes mouth pucker or jaw open
        let confusedScore = squintScore * 0.3 + browDownScore * 0.25
            + browInnerUpScore * 0.2 + mouthPuckerScore * 0.15 + jawOpenScore * 0.1
        scores.append((.confused, confusedScore))

        // Frustrated: brow down, frown, tension
        let frustratedScore = browDownScore * 0.35 + frownScore * 0.3
            + squintScore * 0.15 + cheekPuffScore * 0.1
            + (1.0 - smileScore) * 0.1
        scores.append((.frustrated, frustratedScore))

        // Anxious: mixed signals - brow up + wide eyes + lip tension
        let anxiousScore = browInnerUpScore * 0.3 + eyeWideScore * 0.25
            + mouthPuckerScore * 0.2 + browOuterUpScore * 0.15
            + (1.0 - smileScore) * 0.1
        scores.append((.anxious, anxiousScore))

        // Bored: neutral face with very low overall movement
        let boredScore = (1.0 - overallMovement) * 0.5
            + (1.0 - smileScore) * 0.15 + (1.0 - browDownScore) * 0.15
            + (1.0 - eyeWideScore) * 0.1 + (1.0 - squintScore) * 0.1
        scores.append((.bored, boredScore))

        // Neutral: low activity across all expressive features
        let neutralScore = (1.0 - smileScore) * 0.2 + (1.0 - frownScore) * 0.2
            + (1.0 - browDownScore) * 0.2 + (1.0 - squintScore) * 0.2
            + (1.0 - eyeWideScore) * 0.2
        scores.append((.neutral, neutralScore))

        // Sort by score descending
        scores.sort { $0.1 > $1.1 }

        guard let best = scores.first else {
            return (.neutral, 0)
        }

        // Confidence is based on how much the top score exceeds the runner-up
        let confidence: Float
        if scores.count >= 2 {
            let separation = best.1 - scores[1].1
            // Map separation to confidence: 0 separation = 0.3, 0.3+ separation = 1.0
            confidence = min(1.0, 0.3 + separation * 2.33)
        } else {
            confidence = best.1
        }

        // If bored vs neutral is close and movement is low, prefer bored
        if best.0 == .neutral, overallMovement < 0.05 {
            return (.bored, confidence)
        }

        return (best.0, confidence)
    }

    // MARK: - Blend Shape Helpers

    private func blendShape(_ location: ARFaceAnchor.BlendShapeLocation) -> Float {
        smoothedBlendShapes[location] ?? 0
    }

    private func blendShapeAverage(_ locations: [ARFaceAnchor.BlendShapeLocation]) -> Float {
        guard !locations.isEmpty else { return 0 }
        let sum = locations.reduce(Float(0)) { $0 + (smoothedBlendShapes[$1] ?? 0) }
        return sum / Float(locations.count)
    }

    /// Calculates overall facial movement as the average of all tracked blend shape values.
    private func calculateOverallMovement() -> Float {
        guard !smoothedBlendShapes.isEmpty else { return 0 }
        let sum = smoothedBlendShapes.values.reduce(Float(0), +)
        return sum / Float(smoothedBlendShapes.count)
    }

    // MARK: - Timeline

    private func appendToTimeline(_ sample: ExpressionSample) {
        expressionTimeline.append(sample)
        if expressionTimeline.count > maxTimelineLength {
            expressionTimeline.removeFirst(expressionTimeline.count - maxTimelineLength)
        }
    }

    /// Returns the dominant expression over the timeline window.
    func dominantExpression() -> (ExpressionCategory, Float) {
        guard !expressionTimeline.isEmpty else { return (.neutral, 0) }

        var categoryScores: [ExpressionCategory: Float] = [:]
        for sample in expressionTimeline {
            categoryScores[sample.category, default: 0] += sample.confidence
        }

        guard let best = categoryScores.max(by: { $0.value < $1.value }) else {
            return (.neutral, 0)
        }

        let totalConfidence = categoryScores.values.reduce(0, +)
        let normalizedConfidence = totalConfidence > 0 ? best.value / totalConfidence : 0

        return (best.key, normalizedConfidence)
    }

    // MARK: - Tracking State

    private func handleTrackingStateChange(_ anchor: ARFaceAnchor?) {
        signalQuality = anchor != nil ? .good : .noData
    }

    // MARK: - State Reset

    private func resetState() {
        expressionTimeline.removeAll()
        smoothedBlendShapes.removeAll()
        lastSampleTime = nil
        signalQuality = .noData
    }
}
