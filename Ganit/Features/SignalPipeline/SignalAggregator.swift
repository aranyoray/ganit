import Foundation
import Combine

// MARK: - Signal Aggregator

/// Fuses signals from all providers into a unified SignalSnapshot per question.
/// V1: Touch only. V2: Eye + Face + Touch. V3: + Voice.
@MainActor
class SignalAggregator: ObservableObject {

    @Published var latestSnapshot: SignalSnapshot?
    @Published var engagementState: EngagementState = .neutral

    private let touchProvider: TouchPatternProvider
    private var cancellables = Set<AnyCancellable>()

    // V2 providers
    #if os(iOS)
    private var eyeTrackingProvider: EyeTrackingProvider?
    private var facialAnalysisProvider: FacialAnalysisProvider?
    private var voiceTrackingProvider: VoiceTrackingProvider?
    #endif

    // Signal weights for multimodal fusion
    private struct SignalWeights {
        var touch: Float = 1.0
        var gaze: Float = 0.0
        var expression: Float = 0.0
        var voice: Float = 0.0
    }
    private var weights = SignalWeights()

    // Recent expression samples for temporal smoothing
    private var recentExpressions: [ExpressionSample] = []
    private var recentGazeFixations: [GazeFixation] = []

    // History for engagement classification smoothing
    private var snapshotHistory: [SignalSnapshot] = []
    private let maxHistorySize = 10

    // MARK: - Init

    init(touchProvider: TouchPatternProvider) {
        self.touchProvider = touchProvider
    }

    // MARK: - Configure V2 Providers

    #if os(iOS)
    func configureEyeTracking(_ provider: EyeTrackingProvider) {
        self.eyeTrackingProvider = provider
        weights.gaze = 0.3
        weights.touch = 0.4

        provider.gazePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] fixation in
                self?.recentGazeFixations.append(fixation)
                // Keep last 30 fixations
                if (self?.recentGazeFixations.count ?? 0) > 30 {
                    self?.recentGazeFixations.removeFirst()
                }
            }
            .store(in: &cancellables)
    }

    func configureFacialAnalysis(_ provider: FacialAnalysisProvider) {
        self.facialAnalysisProvider = provider
        weights.expression = 0.3
        weights.touch = 0.3

        provider.expressionPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] sample in
                self?.recentExpressions.append(sample)
                // Keep last 30 samples
                if (self?.recentExpressions.count ?? 0) > 30 {
                    self?.recentExpressions.removeFirst()
                }
            }
            .store(in: &cancellables)
    }

    func configureVoiceTracking(_ provider: VoiceTrackingProvider) {
        self.voiceTrackingProvider = provider
        weights.voice = 0.15
        // Redistribute weights
        weights.touch = 0.25
        weights.gaze = 0.25
        weights.expression = 0.25
    }
    #endif

    // MARK: - Capture Snapshot (Multimodal)

    func captureSnapshot(questionId: String) -> SignalSnapshot {
        var snapshot = SignalSnapshot(
            timestamp: Date(),
            questionId: questionId
        )

        // Touch signals (always available)
        snapshot.responseLatency = touchProvider.responseLatency
        snapshot.hesitationCount = touchProvider.currentHesitationCount
        snapshot.answerChanges = touchProvider.answerChangeCount

        // Eye tracking signals (V2)
        snapshot.gazeFixations = recentGazeFixations
        snapshot.saccadeCount = countSaccades(in: recentGazeFixations)
        snapshot.gazeAvoidanceDuration = calculateGazeAvoidance(in: recentGazeFixations)

        // Facial expression signals (V2)
        if let dominant = dominantExpression(from: recentExpressions) {
            snapshot.dominantExpression = dominant.category
            snapshot.expressionConfidence = dominant.confidence
        }
        snapshot.expressionTimeline = recentExpressions

        // Derive multimodal engagement scores
        snapshot.engagementScore = deriveMultimodalEngagement(from: snapshot)
        snapshot.confusionScore = deriveMultimodalConfusion(from: snapshot)
        snapshot.frustrationScore = deriveMultimodalFrustration(from: snapshot)
        snapshot.anxietyScore = deriveAnxiety(from: snapshot)

        // Update history and classify
        snapshotHistory.append(snapshot)
        if snapshotHistory.count > maxHistorySize {
            snapshotHistory.removeFirst()
        }
        engagementState = EngagementClassifier.classifyWithHistory(snapshotHistory)

        latestSnapshot = snapshot

        // Clear per-question signal data
        recentGazeFixations.removeAll()
        recentExpressions.removeAll()

        return snapshot
    }

    // MARK: - Multimodal Engagement Derivation

    private func deriveMultimodalEngagement(from snapshot: SignalSnapshot) -> Float {
        // Touch-based engagement
        let touchEngagement = deriveTouchEngagement(from: snapshot)

        // Gaze-based engagement (V2): sustained fixations = engaged
        let gazeEngagement: Float
        if !snapshot.gazeFixations.isEmpty {
            let avgFixationDuration = snapshot.gazeFixations.map { Float($0.duration) }.reduce(0, +) / Float(snapshot.gazeFixations.count)
            gazeEngagement = min(1, avgFixationDuration / 2.0) // 2s fixation = max engagement
        } else {
            gazeEngagement = 0.5 // No data: neutral assumption
        }

        // Expression-based engagement (V2)
        let expressionEngagement: Float
        switch snapshot.dominantExpression {
        case .engaged:    expressionEngagement = 0.9
        case .neutral:    expressionEngagement = 0.5
        case .confused:   expressionEngagement = 0.4
        case .bored:      expressionEngagement = 0.1
        case .frustrated: expressionEngagement = 0.3
        case .anxious:    expressionEngagement = 0.3
        case .ambiguous:  expressionEngagement = 0.5
        }

        // Weighted fusion
        return weights.touch * touchEngagement +
               weights.gaze * gazeEngagement +
               weights.expression * expressionEngagement
    }

    private func deriveMultimodalConfusion(from snapshot: SignalSnapshot) -> Float {
        // Touch confusion
        let touchConfusion = Float(min(snapshot.answerChanges, 4)) * 0.25

        // Gaze confusion: high saccade count = scanning/uncertain
        let gazeConfusion: Float = snapshot.gazeFixations.isEmpty ? 0 :
            min(1, Float(snapshot.saccadeCount) / 8.0)

        // Expression confusion
        let expressionConfusion: Float = snapshot.dominantExpression == .confused ?
            snapshot.expressionConfidence : 0

        return weights.touch * touchConfusion +
               weights.gaze * gazeConfusion +
               weights.expression * expressionConfusion
    }

    private func deriveMultimodalFrustration(from snapshot: SignalSnapshot) -> Float {
        // Touch frustration (rage-tapping or slow+hesitant)
        let touchFrustration = deriveTouchFrustration(from: snapshot)

        // Expression frustration
        let expressionFrustration: Float = snapshot.dominantExpression == .frustrated ?
            snapshot.expressionConfidence : 0

        // Gaze frustration: gaze avoidance = giving up
        let gazeAvoidanceFactor: Float = snapshot.gazeAvoidanceDuration > 3 ? 0.6 : 0

        return weights.touch * touchFrustration +
               weights.expression * expressionFrustration +
               weights.gaze * gazeAvoidanceFactor
    }

    private func deriveAnxiety(from snapshot: SignalSnapshot) -> Float {
        // Expression-based anxiety
        let expressionAnxiety: Float = snapshot.dominantExpression == .anxious ?
            snapshot.expressionConfidence : 0

        // Touch-based anxiety: very slow response + high hesitation
        let touchAnxiety: Float = snapshot.responseLatency > 15 && snapshot.hesitationCount > 3 ? 0.5 : 0

        return max(expressionAnxiety, touchAnxiety)
    }

    // MARK: - V1 Touch-Only Derivations (kept for fallback)

    private func deriveTouchEngagement(from snapshot: SignalSnapshot) -> Float {
        let latencyScore: Float
        switch snapshot.responseLatency {
        case ..<3:   latencyScore = 1.0
        case 3..<8:  latencyScore = 0.7
        case 8..<15: latencyScore = 0.4
        default:     latencyScore = 0.2
        }
        let hesitationPenalty = Float(min(snapshot.hesitationCount, 5)) * 0.1
        return max(0, min(1, latencyScore - hesitationPenalty))
    }

    private func deriveTouchFrustration(from snapshot: SignalSnapshot) -> Float {
        let rageTapping: Float = snapshot.responseLatency < 1 && snapshot.answerChanges > 0 ? 0.6 : 0
        let slowFrustration: Float = snapshot.responseLatency > 20 && snapshot.hesitationCount > 2 ? 0.5 : 0
        return min(1, max(rageTapping, slowFrustration))
    }

    // MARK: - Eye Tracking Helpers

    private func countSaccades(in fixations: [GazeFixation]) -> Int {
        guard fixations.count > 1 else { return 0 }
        var saccades = 0
        for i in 1..<fixations.count {
            if fixations[i].region != fixations[i-1].region {
                saccades += 1
            }
        }
        return saccades
    }

    private func calculateGazeAvoidance(in fixations: [GazeFixation]) -> TimeInterval {
        fixations
            .filter { $0.region == .elsewhere }
            .map(\.duration)
            .reduce(0, +)
    }

    private func dominantExpression(from samples: [ExpressionSample]) -> ExpressionSample? {
        guard !samples.isEmpty else { return nil }
        // Return the most frequent expression with highest confidence
        let grouped = Dictionary(grouping: samples, by: \.category)
        return grouped
            .max(by: { $0.value.count < $1.value.count })?
            .value
            .max(by: { $0.confidence < $1.confidence })
    }
}
