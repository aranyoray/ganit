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
        let arView = context.coordinator.createARView()

        // Additional config: disable collaboration
        if let config = arView.session.configuration as? ARWorldTrackingConfiguration {
            config.isCollaborationEnabled = false
            arView.session.run(config)
        }

        // Double tap: fun fact about the number
        let doubleTapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(WalkAroundCoordinator.handleDoubleTap(_:))
        )
        doubleTapGesture.numberOfTapsRequired = 2
        arView.addGestureRecognizer(doubleTapGesture)

        // Single tap waits for double tap to fail
        if let tapGesture = arView.gestureRecognizers?.first(where: {
            ($0 as? UITapGestureRecognizer)?.numberOfTapsRequired == 1
        }) {
            tapGesture.require(toFail: doubleTapGesture)
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> WalkAroundCoordinator {
        WalkAroundCoordinator(
            onReady: onReady,
            onStatusUpdate: onStatusUpdate,
            onNumberTapped: onNumberTapped
        )
    }
}

// MARK: - Walk Around Coordinator

class WalkAroundCoordinator: ARSceneCoordinator {
    var onNumberTapped: (String) -> Void
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

    init(onReady: @escaping () -> Void,
         onStatusUpdate: @escaping (String) -> Void,
         onNumberTapped: @escaping (String) -> Void) {
        self.onNumberTapped = onNumberTapped
        super.init(onReady: onReady, onStatusUpdate: onStatusUpdate)
    }

    // MARK: - Plane Detection Override

    /// WalkAroundScene needs a larger plane before placing content.
    override func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard !hasPlacedContent, let arView = arView else { return }

        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor,
               planeAnchor.alignment == .horizontal,
               planeAnchor.planeExtent.width > 0.5, planeAnchor.planeExtent.height > 0.5 {
                hasPlacedContent = true
                onReady()
                onStatusUpdate("Numbers placed! Walk around to explore.")
                placeNumberBlocksInCircle(on: planeAnchor, in: arView)
                break
            }
        }
    }

    // MARK: - Scene Construction

    private func placeNumberBlocksInCircle(on anchor: ARPlaneAnchor, in arView: ARView) {
        let anchorEntity = AnchorEntity(anchor: anchor)
        let blockSize: Float = 0.3
        let circleRadius: Float = 1.2
        let numberCount = 9

        for i in 1...numberCount {
            let angle = (Float(i - 1) / Float(numberCount)) * 2.0 * .pi
            let x = cos(angle) * circleRadius
            let z = sin(angle) * circleRadius

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

            let lookDirection = SIMD3<Float>(-x, 0, -z)
            let normalizedDir = normalize(lookDirection)
            let yaw = atan2(normalizedDir.x, normalizedDir.z)
            entity.orientation = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))

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

    // MARK: - Gesture Handlers

    override func handleEntityTap(_ entity: Entity, in arView: ARView) {
        guard entity.name.hasPrefix("number_") else { return }
        let numberStr = entity.name.replacingOccurrences(of: "number_", with: "")

        speak(numberStr, rate: 0.4, pitch: 1.0)

        DispatchQueue.main.async {
            self.onNumberTapped(numberStr)
        }
    }

    @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView = recognizer.view as? ARView else { return }
        let location = recognizer.location(in: arView)

        if let entity = arView.entity(at: location),
           entity.name.hasPrefix("number_"),
           let number = Int(entity.name.replacingOccurrences(of: "number_", with: "")) {

            animateTapFeedback(on: entity)

            let fact = funFacts[number] ?? "Number \(number) is great!"
            speak(fact, rate: 0.4, pitch: 1.0)

            DispatchQueue.main.async {
                self.onNumberTapped("\(number): \(fact)")
            }
        }
    }
}
#endif
