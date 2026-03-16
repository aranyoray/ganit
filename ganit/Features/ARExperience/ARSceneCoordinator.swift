#if os(iOS)
import SwiftUI
import RealityKit
import ARKit
import AVFoundation

// MARK: - Base AR Scene Coordinator
// Shared behavior for all AR learning scenes:
//   ARView setup -> plane detection -> content placement -> gestures -> speech
// Subclasses override placeContent() and handleEntityTap()

class ARSceneCoordinator: NSObject, ARSessionDelegate {
    weak var arView: ARView?
    var hasPlacedContent = false
    var onReady: () -> Void
    var onStatusUpdate: (String) -> Void
    let synthesizer = AVSpeechSynthesizer()

    init(onReady: @escaping () -> Void, onStatusUpdate: @escaping (String) -> Void) {
        self.onReady = onReady
        self.onStatusUpdate = onStatusUpdate
    }

    // MARK: - ARView Factory

    /// Create and configure an ARView with world tracking, horizontal plane detection,
    /// tap gesture, and optional pan gesture.
    func createARView(enablePan: Bool = false) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
        arView.session.delegate = self

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)

        if enablePan {
            let panGesture = UIPanGestureRecognizer(
                target: self,
                action: #selector(handlePan(_:))
            )
            arView.addGestureRecognizer(panGesture)
        }

        self.arView = arView
        return arView
    }

    // MARK: - ARSessionDelegate (plane detection)

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard !hasPlacedContent else { return }

        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor,
               planeAnchor.alignment == .horizontal {
                hasPlacedContent = true
                DispatchQueue.main.async { [weak self] in
                    self?.onReady()
                    self?.onStatusUpdate("Surface detected!")
                }
                placeContent(on: planeAnchor, in: session)
                break
            }
        }
    }

    // MARK: - Override Points

    /// Override to place scene-specific content when a horizontal plane is detected.
    func placeContent(on planeAnchor: ARPlaneAnchor, in session: ARSession) {
        // Subclasses override
    }

    /// Override to handle a tap on a specific entity.
    func handleEntityTap(_ entity: Entity, in arView: ARView) {
        // Subclasses override
    }

    /// Override to handle pan gesture.
    func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        // Subclasses override
    }

    // MARK: - Gesture Routing

    /// Shared tap handler: detects entity under tap, applies scale animation, then
    /// delegates to handleEntityTap().
    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView = arView else { return }
        let location = recognizer.location(in: arView)

        if let entity = arView.entity(at: location) {
            animateTapFeedback(on: entity)
            handleEntityTap(entity, in: arView)
        }
    }

    /// Shared pan handler: routes to handlePanGesture() for subclass-specific logic.
    @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
        handlePanGesture(recognizer)
    }

    // MARK: - Speech

    /// Speak text using AVSpeechSynthesizer with child-friendly defaults.
    func speak(_ text: String, rate: Float = 0.45, pitch: Float = 1.1) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    // MARK: - Tap Feedback Animation

    /// Scale-bounce animation on an entity to give visual tap feedback.
    func animateTapFeedback(on entity: Entity, scale: Float = 1.3) {
        var transform = entity.transform
        transform.scale = SIMD3(repeating: scale)
        entity.move(to: transform, relativeTo: entity.parent, duration: 0.15)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            var reset = entity.transform
            reset.scale = SIMD3(repeating: 1.0)
            entity.move(to: reset, relativeTo: entity.parent, duration: 0.15)
        }
    }
}

// MARK: - Base AR Scene View (SwiftUI wrapper)

/// Generic UIViewRepresentable that creates an ARView from any ARSceneCoordinator subclass.
struct BaseARSceneView<Coordinator: ARSceneCoordinator>: UIViewRepresentable {
    var enablePan: Bool = false
    var onReady: () -> Void = {}
    var onStatusUpdate: (String) -> Void = { _ in }
    var coordinatorFactory: ((@escaping () -> Void, @escaping (String) -> Void) -> Coordinator)

    func makeUIView(context: Context) -> ARView {
        context.coordinator.createARView(enablePan: enablePan)
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        coordinatorFactory(onReady, onStatusUpdate)
    }
}
#endif
