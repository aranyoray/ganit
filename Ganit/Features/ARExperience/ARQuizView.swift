import SwiftUI
import RealityKit
import ARKit
import AVFoundation

// MARK: - AR Quiz View

/// SwiftUI wrapper for RealityKit AR experience.
/// V1: 3D number blocks on a horizontal plane, tap to hear spoken.
struct ARQuizView: View {
    let question: MCQQuestion?
    @State private var arReady = false
    @State private var statusMessage = "Point your camera at a flat surface..."

    var body: some View {
        ZStack {
            ARViewContainer(
                question: question,
                onReady: { arReady = true },
                onStatusUpdate: { statusMessage = $0 }
            )
            .edgesIgnoringSafeArea(.all)

            VStack {
                if !arReady {
                    Text(statusMessage)
                        .font(.callout)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.top, 60)
                }
                Spacer()

                if let question = question {
                    VStack(spacing: 8) {
                        Text(question.question)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                        Text("Tap the number blocks to count!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
        .navigationTitle("AR Math")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - AR View Container

#if os(iOS)
struct ARViewContainer: UIViewRepresentable {
    let question: MCQQuestion?
    var onReady: () -> Void
    var onStatusUpdate: (String) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure world tracking with plane detection
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic

        // On A12+ devices, enable simultaneous face tracking for signals
        if ARFaceTrackingConfiguration.isSupported {
            config.userFaceTrackingEnabled = true
        }

        arView.session.run(config)
        arView.session.delegate = context.coordinator

        // Add tap gesture for counting interaction
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.currentQuestion = question
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onReady: onReady, onStatusUpdate: onStatusUpdate)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        var currentQuestion: MCQQuestion?
        var hasPlacedContent = false
        var onReady: () -> Void
        var onStatusUpdate: (String) -> Void
        var numberEntities: [ModelEntity] = []
        var tappedCount = 0

        init(onReady: @escaping () -> Void, onStatusUpdate: @escaping (String) -> Void) {
            self.onReady = onReady
            self.onStatusUpdate = onStatusUpdate
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard !hasPlacedContent else { return }

            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor,
                   planeAnchor.alignment == .horizontal {
                    hasPlacedContent = true
                    onReady()
                    onStatusUpdate("Surface detected! Placing number blocks...")

                    // Place number blocks on the detected plane
                    placeNumberBlocks(on: planeAnchor, in: session)
                    break
                }
            }
        }

        private func placeNumberBlocks(on anchor: ARPlaneAnchor, in session: ARSession) {
            // V1: Create simple 3D number block entities
            // Numbers 1-5 placed in a row on the surface
            for i in 1...5 {
                let mesh = MeshResource.generateBox(
                    size: 0.08,
                    cornerRadius: 0.01
                )
                let material = SimpleMaterial(
                    color: numberColor(i),
                    isMetallic: false
                )
                let entity = ModelEntity(mesh: mesh, materials: [material])

                // Position blocks in a row
                let xOffset = Float(i - 3) * 0.12
                entity.position = SIMD3(xOffset, 0.04, 0)
                entity.name = "number_\(i)"

                // Enable tap interaction
                entity.generateCollisionShapes(recursive: false)

                numberEntities.append(entity)
            }
        }

        private func numberColor(_ n: Int) -> UIColor {
            let colors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink]
            return colors[(n - 1) % colors.count]
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = recognizer.view as? ARView else { return }
            let location = recognizer.location(in: arView)

            if let entity = arView.entity(at: location),
               entity.name.hasPrefix("number_") {
                tappedCount += 1

                // Visual feedback: scale up briefly
                var transform = entity.transform
                transform.scale = SIMD3(repeating: 1.3)
                entity.move(to: transform, relativeTo: entity.parent, duration: 0.15)

                // Speak the number
                let numberStr = entity.name.replacingOccurrences(of: "number_", with: "")
                speakNumber(numberStr)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    var resetTransform = entity.transform
                    resetTransform.scale = SIMD3(repeating: 1.0)
                    entity.move(to: resetTransform, relativeTo: entity.parent, duration: 0.15)
                }
            }
        }

        private let synthesizer = AVSpeechSynthesizer()

        private func speakNumber(_ number: String) {
            let utterance = AVSpeechUtterance(string: number)
            utterance.rate = 0.4
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(utterance)
        }
    }
}
#else
// macOS fallback
struct ARViewContainer: View {
    let question: MCQQuestion?
    var onReady: () -> Void
    var onStatusUpdate: (String) -> Void

    var body: some View {
        Text("AR is only available on iOS devices with ARKit support.")
            .padding()
    }
}
#endif
