import Foundation
import Combine

// MARK: - Touch Pattern Provider

/// Tracks touch interaction patterns during quiz sessions.
/// Works on all devices (no TrueDepth camera required).
@MainActor
class TouchPatternProvider: ObservableObject, TouchPatternProviderProtocol {

    // MARK: - Signal Provider

    var isAvailable: Bool { true }  // Touch works on all iOS devices
    var signalQuality: SignalQuality { .good }

    // MARK: - Publishers

    private let touchSubject = PassthroughSubject<TouchEvent, Never>()
    var touchEventPublisher: AnyPublisher<TouchEvent, Never> {
        touchSubject.eraseToAnyPublisher()
    }

    // MARK: - State

    private var questionDisplayTime: Date?
    private var firstTouchTime: Date?
    private var hoverCount: Int = 0
    private var selectedOptions: [Int] = []
    private(set) var currentHesitationCount: Int = 0

    // MARK: - Lifecycle

    func start() {
        // Touch tracking is always active
    }

    func stop() {
        reset()
    }

    // MARK: - Event Recording

    func questionDidAppear() {
        reset()
        questionDisplayTime = Date()
    }

    func optionSelected(index: Int) {
        let now = Date()

        // First touch records latency
        if firstTouchTime == nil {
            firstTouchTime = now
            touchSubject.send(TouchEvent(
                type: .firstTouch,
                timestamp: now,
                optionIndex: index,
                pressure: nil
            ))
        }

        selectedOptions.append(index)

        touchSubject.send(TouchEvent(
            type: .optionSelect,
            timestamp: now,
            optionIndex: index,
            pressure: nil
        ))
    }

    func optionDeselected(index: Int) {
        currentHesitationCount += 1
        touchSubject.send(TouchEvent(
            type: .optionDeselect,
            timestamp: Date(),
            optionIndex: index,
            pressure: nil
        ))
    }

    func answerSubmitted() {
        touchSubject.send(TouchEvent(
            type: .answerSubmit,
            timestamp: Date(),
            optionIndex: selectedOptions.last,
            pressure: nil
        ))
    }

    // MARK: - Computed Metrics

    /// Time from question display to first interaction.
    var responseLatency: TimeInterval {
        guard let display = questionDisplayTime, let first = firstTouchTime else { return 0 }
        return first.timeIntervalSince(display)
    }

    /// Number of times user changed their selected option.
    var answerChangeCount: Int {
        guard selectedOptions.count > 1 else { return 0 }
        var changes = 0
        for i in 1..<selectedOptions.count {
            if selectedOptions[i] != selectedOptions[i - 1] {
                changes += 1
            }
        }
        return changes
    }

    // MARK: - Private

    private func reset() {
        questionDisplayTime = nil
        firstTouchTime = nil
        hoverCount = 0
        selectedOptions = []
        currentHesitationCount = 0
    }
}
