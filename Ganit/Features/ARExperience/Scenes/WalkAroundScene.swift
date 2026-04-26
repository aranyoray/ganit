import SwiftUI
import RealityKit
import ARKit
import AVFoundation

// MARK: - Walk Around Scene

/// V3 room-scale AR: large 3D number blocks placed at room scale (0.3m each).
/// Child physically walks around them, seeing from different angles.
/// Numbers placed in a circle/arc formation with spoken feedback on tap.
struct WalkAroundScene: View {
    @State private var arReady = false
    @State private var statusMessage = "Walk around and look for a flat surface..."
    @State private var tappedNumber: String?

    var body: some View {
        ZStack {
            #if os(iOS)
            WalkAroundARContainer(
                onReady: { arReady = true },
                onStatusUpdate: { statusMessage = $0 },
                onNumberTapped: { tappedNumber = $0 }
            )
            .edgesIgnoringSafeArea(.all)
            #else
            Text("AR Walk-Around is only available on iOS devices with ARKit support.")
                .padding()
            #endif

            VStack {
                if !arReady {
                    Text(statusMessage)
                        .font(.system(size: 18, weight: .medium))
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(.top, 60)
                }
                Spacer()

                VStack(spacing: 8) {
                    if let number = tappedNumber {
                        Text(number)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .transition(.scale)
                    }

                    Text("Walk around the numbers and tap to explore!")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding()
            }
        }
        .navigationTitle("Walk Around")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Walk Around AR Container (iOS)

#if os(iOS)
struct WalkAroundARContainer: UIViewRepresentable {
    var onReady: () -> Void
    var onStatusUpdate: (String) -> Void
    var onNumberTapped: (String) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure world tracking with persistent anchors
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        config.isCollaborationEnabled = false

        arView.session.run(config)
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView

        // Single tap: hear the number spoken
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSingleTap(_:))
        )
        tapGesture.numberOfTapsRequired = 1
        arView.addGestureRecognizer(tapGesture)

        // Double tap: fun fact about the number
        let doubleTapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTapGesture.numberOfTapsRequired = 2
        arView.addGestureRecognizer(doubleTapGesture)

        // Single tap waits for double tap to fail
        tapGesture.require(toFail: doubleTapGesture)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onReady: onReady, onStatusUpdate: onStatusUpdate, onNumberTapped: onNumberTapped)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        var hasPlacedContent = false
        var onReady: () -> Void
        var onStatusUpdate: (String) -> Void
        var onNumberTapped: (String) -> Void

        private let synthesizer = AVSpeechSynthesizer()
        private var numberEntities: [ModelEntity] = []

        // Number fun facts
        private let funFacts: [Int: String] = [
            1: "One is the loneliest number, but also the first counting number!",
            2: "Two is the only even prime number.",
            3: "Three sides make a triangle, the strongest shape.",
            4: "Four is the number of seasons in a year.",
            5: "Five fingers on each hand help us count!",
            6: "Six is a perfect number: 1 plus 2 plus 3 equals 6.",
            7: "Seven days make a week.",
            8: "An octopus has eight arms!",
            9: "Nine planets used to be in our solar system.",
        ]

        init(
            onReady: @escaping () -> Void,
            onStatusUpdate: @escaping (String) -> Void,
            onNumberTapped: @escaping (String) -> Void
        ) {
            self.onReady = onReady
            self.onStatusUpdate = onStatusUpdate
            self.onNumberTapped = onNumberTapped
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard !hasPlacedContent, let arView = arView else { return }

            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor,
                   planeAnchor.alignment == .horizontal,
                   planeAnchor.extent.x > 0.5, planeAnchor.extent.z > 0.5 {
                    hasPlacedContent = true
                    onReady()
                    onStatusUpdate("Numbers placed! Walk around to explore.")
                    placeNumberBlocksInCircle(on: planeAnchor, in: arView)
                    break
                }
            }
        }

        /// Places numbers 1-9 in a circle/arc on the detected plane at room scale.
        private func placeNumberBlocksInCircle(on anchor: ARPlaneAnchor, in arView: ARView) {
            let anchorEntity = AnchorEntity(anchor: anchor)
            let blockSize: Float = 0.3
            let circleRadius: Float = 1.2
            let numberCount = 9

            for i in 1...numberCount {
                // Position in a circle
                let angle = (Float(i - 1) / Float(numberCount)) * 2.0 * .pi
                let x = cos(angle) * circleRadius
                let z = sin(angle) * circleRadius

                // Create the block
                let mesh = MeshResource.generateBox(
                    size: blockSize,
                    cornerRadius: blockSize * 0.1
                )
                let material = SimpleMaterial(
                    color: blockColor(for: i),
                    isMetallic: false
                )
                let entity = ModelEntity(mesh: mesh, materials: [material])
                entity.position = SIMD3(x, blockSize / 2, z)
                entity.name = "number_\(i)"

                // Rotate block to face center
                let lookDirection = SIMD3<Float>(-x, 0, -z)
                let normalizedDir = normalize(lookDirection)
                let yaw = atan2(normalizedDir.x, normalizedDir.z)
                entity.orientation = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))

                // Enable collision for tap detection
                entity.generateCollisionShapes(recursive: false)

                anchorEntity.addChild(entity)
                numberEntities.append(entity)
            }

            arView.scene.addAnchor(anchorEntity)
        }

        private func blockColor(for number: Int) -> UIColor {
            let colors: [UIColor] = [
                .systemBlue, .systemTeal, .systemGreen, .systemYellow,
                .systemOrange, .systemPink, .systemPurple, .systemIndigo, .systemMint
            ]
            return colors[(number - 1) % colors.count]
        }

        // MARK: - Tap Handlers

        @objc func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = recognizer.view as? ARView else { return }
            let location = recognizer.location(in: arView)

            if let entity = arView.entity(at: location),
               entity.name.hasPrefix("number_") {
                let numberStr = entity.name.replacingOccurrences(of: "number_", with: "")

                // Visual feedback: bounce scale
                animateTap(entity)

                // Speak the number
                speak(numberStr)

                DispatchQueue.main.async {
                    self.onNumberTapped(numberStr)
                }
            }
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = recognizer.view as? ARView else { return }
            let location = recognizer.location(in: arView)

            if let entity = arView.entity(at: location),
               entity.name.hasPrefix("number_"),
               let number = Int(entity.name.replacingOccurrences(of: "number_", with: "")) {

                animateTap(entity)

                // Speak fun fact
                let fact = funFacts[number] ?? "Number \(number) is great!"
                speak(fact)

                DispatchQueue.main.async {
                    self.onNumberTapped("\(number): \(fact)")
                }
            }
        }

        private func animateTap(_ entity: Entity) {
            var scaleUp = entity.transform
            scaleUp.scale = SIMD3(repeating: 1.3)
            entity.move(to: scaleUp, relativeTo: entity.parent, duration: 0.15)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                var scaleDown = entity.transform
                scaleDown.scale = SIMD3(repeating: 1.0)
                entity.move(to: scaleDown, relativeTo: entity.parent, duration: 0.15)
            }
        }

        private func speak(_ text: String) {
            synthesizer.stopSpeaking(at: .immediate)
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = 0.4
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(utterance)
        }
    }
}
#endif
