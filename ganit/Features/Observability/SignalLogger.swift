import Foundation
import os.log

// MARK: - Signal Logger

/// Structured os_log logging for the signal pipeline and curriculum engine.
enum SignalLogger {

    private static let signalLog = Logger(subsystem: "com.ganit.app", category: "signals")
    private static let curriculumLog = Logger(subsystem: "com.ganit.app", category: "curriculum")
    private static let riskLog = Logger(subsystem: "com.ganit.app", category: "risk")
    private static let arLog = Logger(subsystem: "com.ganit.app", category: "ar")

    // MARK: - Signal Pipeline

    static func signalCaptured(_ snapshot: SignalSnapshot) {
        signalLog.info("""
            Signal captured: question=\(snapshot.questionId) \
            engagement=\(String(format: "%.2f", snapshot.engagementScore)) \
            confusion=\(String(format: "%.2f", snapshot.confusionScore)) \
            frustration=\(String(format: "%.2f", snapshot.frustrationScore)) \
            latency=\(String(format: "%.1f", snapshot.responseLatency))s \
            hesitations=\(snapshot.hesitationCount) \
            changes=\(snapshot.answerChanges)
            """)
    }

    static func signalProviderStarted(_ provider: String, available: Bool) {
        signalLog.info("Signal provider \(provider): available=\(available)")
    }

    static func signalProviderStopped(_ provider: String) {
        signalLog.info("Signal provider stopped: \(provider)")
    }

    // MARK: - Curriculum Engine

    static func difficultyChanged(from: DifficultyLevel, to: DifficultyLevel, reason: String) {
        curriculumLog.info("Difficulty changed: \(from.rawValue) -> \(to.rawValue) reason=\(reason)")
    }

    static func modalitySuggested(_ modality: LearningModality, reason: String) {
        curriculumLog.info("Modality suggested: \(modality.rawValue) reason=\(reason)")
    }

    static func accommodationAdded(_ accommodation: Accommodation, reason: String) {
        curriculumLog.info("Accommodation added: \(accommodation.rawValue) reason=\(reason)")
    }

    // MARK: - Risk Assessment

    static func screeningCompleted(_ result: ScreeningResult) {
        riskLog.info("""
            Screening: condition=\(result.condition.rawValue) \
            score=\(String(format: "%.2f", result.indicatorScore)) \
            confidence=\(String(format: "%.2f", result.confidence)) \
            sessions=\(result.sessionCount) \
            recommend=\(result.shouldRecommendProfessional)
            """)
    }

    static func insufficientData(sessions: Int, required: Int) {
        riskLog.info("Insufficient screening data: \(sessions)/\(required) sessions")
    }

    // MARK: - AR

    static func arSessionStarted(faceTrackingAvailable: Bool) {
        arLog.info("AR session started: faceTracking=\(faceTrackingAvailable)")
    }

    static func arPlaneDetected() {
        arLog.info("AR horizontal plane detected")
    }

    static func arEntityTapped(_ entityName: String) {
        arLog.info("AR entity tapped: \(entityName)")
    }

    // MARK: - General

    static func sessionStarted(userId: String, userGroup: UserGroup, mode: QuizMode?) {
        signalLog.info("Session started: user=\(userId) group=\(userGroup.rawValue) mode=\(mode?.rawValue ?? "none")")
    }

    static func sessionEnded(questionCount: Int, accuracy: Double, duration: TimeInterval) {
        signalLog.info("Session ended: questions=\(questionCount) accuracy=\(String(format: "%.0f", accuracy * 100))% duration=\(String(format: "%.0f", duration))s")
    }
}
