import Foundation
import AVFoundation
import Combine
import Speech

// MARK: - Voice Tracking Provider (V3)

/// Tracks speech patterns: rate, hesitation, confidence indicators.
/// On-device speech recognition for privacy-first voice signal capture.
#if os(iOS)
@MainActor
class VoiceTrackingProvider: ObservableObject, SignalProvider {

    @Published var isRecording = false
    @Published var speechRate: Double = 0       // words per second
    @Published var hesitationCount: Int = 0     // "um", "uh", pauses
    @Published var confidenceLevel: Float = 0.5 // 0-1, derived from speech patterns

    // SignalProvider
    var isAvailable: Bool {
        AVAudioApplication.shared.recordPermission == .granted &&
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    var signalQuality: SignalQuality { isRecording ? .good : .noData }

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var wordTimestamps: [Date] = []
    private let hesitationWords = Set(["um", "uh", "hmm", "uhh", "umm", "er", "like"])

    // MARK: - Lifecycle

    func start() {
        guard isAvailable, !isRecording else { return }
        requestPermissionsAndStart()
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    // MARK: - Permission

    private func requestPermissionsAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard status == .authorized else { return }
                self?.startRecognition()
            }
        }
    }

    // MARK: - Speech Recognition

    private func startRecognition() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }

        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true  // Privacy: on-device only

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.processTranscription(result)
                }

                if error != nil || (result?.isFinal ?? false) {
                    // Restart recognition for continuous monitoring
                    if self.isRecording {
                        self.stop()
                        self.start()
                    }
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            SignalLogger.signalProviderStarted("VoiceTracking", available: false) // Audio engine failed to start: \(error)")
        }
    }

    // MARK: - Analysis

    private func processTranscription(_ result: SFSpeechRecognitionResult) {
        let transcript = result.bestTranscription
        let words = transcript.segments.map { $0.substring.lowercased() }

        // Track hesitations
        let newHesitations = words.filter { hesitationWords.contains($0) }.count
        hesitationCount = newHesitations

        // Track speech rate (words per second)
        let now = Date()
        wordTimestamps.append(now)
        wordTimestamps = wordTimestamps.filter { now.timeIntervalSince($0) < 10 } // Last 10 seconds

        if wordTimestamps.count > 1, let first = wordTimestamps.first {
            let duration = now.timeIntervalSince(first)
            speechRate = duration > 0 ? Double(wordTimestamps.count) / duration : 0
        }

        // Derive confidence from speech patterns
        // Fast, steady speech = confident. Slow with hesitations = uncertain.
        let rateScore: Float = speechRate > 1.5 ? 0.8 : (speechRate > 0.8 ? 0.5 : 0.3)
        let hesitationPenalty = Float(min(hesitationCount, 5)) * 0.1
        confidenceLevel = max(0, min(1, rateScore - hesitationPenalty))
    }

    // MARK: - Snapshot Data

    /// Returns current voice signal data for inclusion in SignalSnapshot.
    var currentVoiceSignal: VoiceSignal {
        VoiceSignal(
            speechRate: speechRate,
            hesitationCount: hesitationCount,
            confidenceLevel: confidenceLevel,
            isActive: isRecording
        )
    }
}

struct VoiceSignal: Codable {
    let speechRate: Double
    let hesitationCount: Int
    let confidenceLevel: Float
    let isActive: Bool
}
#endif
