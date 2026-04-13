import Foundation
import Combine

// MARK: - Signal Provider Protocol

/// All signal sources (eye tracking, facial analysis, touch patterns) conform to this.
/// Protocol-based design enables future signal sources (voice, Apple Watch) to plug in
/// with zero changes to the aggregator or classifier.
protocol SignalProvider: AnyObject {
    var isAvailable: Bool { get }
    var signalQuality: SignalQuality { get }
    func start()
    func stop()
}

// MARK: - Eye Tracking Provider Protocol

protocol EyeTrackingProviderProtocol: SignalProvider {
    var gazePublisher: AnyPublisher<GazeFixation, Never> { get }
}

// MARK: - Facial Analysis Provider Protocol

protocol FacialAnalysisProviderProtocol: SignalProvider {
    var expressionPublisher: AnyPublisher<ExpressionSample, Never> { get }
}

// MARK: - Touch Pattern Provider Protocol

protocol TouchPatternProviderProtocol: SignalProvider {
    var touchEventPublisher: AnyPublisher<TouchEvent, Never> { get }
    func questionDidAppear()
    func optionSelected(index: Int)
    func optionDeselected(index: Int)
    func answerSubmitted()
}

// MARK: - Touch Event

struct TouchEvent: Codable {
    let type: TouchEventType
    let timestamp: Date
    let optionIndex: Int?
    let pressure: Float?
}

enum TouchEventType: String, Codable {
    case firstTouch          // First interaction after question display
    case optionHover         // Hovering/lingering on an option
    case optionSelect        // Selecting an option
    case optionDeselect      // Changing mind
    case answerSubmit        // Final submission
}
