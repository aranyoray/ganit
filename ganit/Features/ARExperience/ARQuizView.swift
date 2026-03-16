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
        let arView = context.coordinator.createARView()

        // On A12+ devices, enable simultaneous face tracking for signals
        if ARFaceTrackingConfiguration.isSupported,
           let config = arView.session.configuration as? ARWorldTrackingConfiguration {
            config.userFaceTrackingEnabled = true
            arView.session.run(config)
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.currentQuestion = question
    }

    func makeCoordinator() -> ARQuizCoordinator {
        ARQuizCoordinator(onReady: onReady, onStatusUpdate: onStatusUpdate)
    }
}

// MARK: - AR Quiz Coordinator

class ARQuizCoordinator: ARSceneCoordinator {
    var currentQuestion: MCQQuestion?
    var numberEntities: [ModelEntity] = []
    var tappedCount = 0

    override func placeContent(on planeAnchor: ARPlaneAnchor, in session: ARSession) {
        onStatusUpdate("Surface detected! Placing number blocks...")
        placeNumberBlocks(on: planeAnchor, in: session)
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

            let xOffset = Float(i - 3) * 0.12
            entity.position = SIMD3(xOffset, 0.04, 0)
            entity.name = "number_\(i)"

            entity.generateCollisionShapes(recursive: false)

            numberEntities.append(entity)
        }
    }

    private func numberColor(_ n: Int) -> UIColor {
        let colors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink]
        return colors[(n - 1) % colors.count]
    }

    override func handleEntityTap(_ entity: Entity, in arView: ARView) {
        guard entity.name.hasPrefix("number_") else { return }

        tappedCount += 1

        let numberStr = entity.name.replacingOccurrences(of: "number_", with: "")
        speak(numberStr, rate: 0.4, pitch: 1.0)
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
