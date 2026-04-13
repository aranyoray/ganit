import SwiftUI
import RealityKit
import ARKit
import AVFoundation

// MARK: - Place Value AR Scene

/// V2 Interactive AR scene for learning place value (ones, tens, hundreds).
/// Unit cubes, rods, and flats on a detected plane.
/// Tap a rod to decompose into 10 cubes; tap 10 grouped cubes to compose a rod.
struct PlaceValueScene: View {
    @State private var targetNumber: Int
    @State private var statusMessage = "Point your camera at a flat surface..."
    @State private var arReady = false
    @State private var currentTotal: String?

    init(number: Int = 34) {
        _targetNumber = State(initialValue: number)
    }

    var body: some View {
        ZStack {
            #if os(iOS)
            PlaceValueARContainer(
                targetNumber: targetNumber,
                onReady: { arReady = true },
                onStatusUpdate: { statusMessage = $0 },
                onTotalUpdate: { currentTotal = $0 }
            )
            .edgesIgnoringSafeArea(.all)
            #else
            Text("AR is only available on iOS devices with ARKit support.")
                .padding()
            #endif

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

                VStack(spacing: 8) {
                    Text("Place Value")
                        .font(.title3.bold())

                    if let total = currentTotal {
                        Text(total)
                            .font(.title2.bold())
                            .foregroundColor(.blue)
                    }

                    HStack(spacing: 16) {
                        LegendDot(color: .systemBlue, label: "Ones")
                        LegendDot(color: .systemGreen, label: "Tens")
                        LegendDot(color: .systemRed, label: "Hundreds")
                    }

                    Text("Tap a rod to break into 10 cubes. Tap 10 cubes to make a rod.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding()
            }
        }
        .navigationTitle("AR Place Value")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Small colored dot with label for the legend UI.
private struct LegendDot: View {
    let color: UIColor
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(color))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
        }
    }
}

// MARK: - iOS AR Container

#if os(iOS)
struct PlaceValueARContainer: UIViewRepresentable {
    let targetNumber: Int
    var onReady: () -> Void
    var onStatusUpdate: (String) -> Void
    var onTotalUpdate: (String) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
        arView.session.delegate = context.coordinator

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(PlaceValueCoordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)

        context.coordinator.arView = arView
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> PlaceValueCoordinator {
        PlaceValueCoordinator(
            targetNumber: targetNumber,
            onReady: onReady,
            onStatusUpdate: onStatusUpdate,
            onTotalUpdate: onTotalUpdate
        )
    }
}

// MARK: - Place Value Coordinator

class PlaceValueCoordinator: NSObject, ARSessionDelegate {
    weak var arView: ARView?
    let targetNumber: Int
    var onReady: () -> Void
    var onStatusUpdate: (String) -> Void
    var onTotalUpdate: (String) -> Void

    private var hasPlacedContent = false
    private let synthesizer = AVSpeechSynthesizer()

    // Scene entities
    private var sceneAnchor: AnchorEntity?

    // Tracking current decomposition
    private var hundreds: Int = 0
    private var tens: Int = 0
    private var ones: Int = 0

    // Entity lists by type
    private var hundredEntities: [ModelEntity] = []
    private var tenEntities: [ModelEntity] = []
    private var oneEntities: [ModelEntity] = []

    // Sizes
    private let cubeSize: Float = 0.02       // unit cube (ones)
    private let rodWidth: Float = 0.02       // rod cross-section
    private let rodLength: Float = 0.2       // rod length (10 cubes)
    private let flatSize: Float = 0.2        // flat side (10x10 cubes)
    private let flatHeight: Float = 0.02     // flat thickness

    // Colors
    private let onesColor: UIColor = .systemBlue
    private let tensColor: UIColor = .systemGreen
    private let hundredsColor: UIColor = .systemRed

    init(targetNumber: Int,
         onReady: @escaping () -> Void,
         onStatusUpdate: @escaping (String) -> Void,
         onTotalUpdate: @escaping (String) -> Void) {
        self.targetNumber = targetNumber
        self.onReady = onReady
        self.onStatusUpdate = onStatusUpdate
        self.onTotalUpdate = onTotalUpdate
    }

    // MARK: - ARSessionDelegate

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
                placeNumber(targetNumber)

                let tensInNumber = (targetNumber / 10) % 10
                speak("How many tens are in \(targetNumber)? There are \(tensInNumber) tens!")
                break
            }
        }
    }

    // MARK: - Scene Construction

    private func placeNumber(_ number: Int) {
        guard let arView = arView else { return }

        // Remove old content
        sceneAnchor?.removeFromParent()
        hundredEntities.removeAll()
        tenEntities.removeAll()
        oneEntities.removeAll()

        hundreds = number / 100
        tens = (number % 100) / 10
        ones = number % 10

        let anchor = AnchorEntity(plane: .horizontal)
        anchor.name = "placeValueScene"

        // Place hundreds (flats) on the left
        for i in 0..<hundreds {
            let flat = createFlat(index: i)
            flat.position = SIMD3<Float>(
                -0.25,
                flatHeight / 2 + Float(i) * (flatHeight + 0.005),
                0
            )
            anchor.addChild(flat)
            hundredEntities.append(flat)
        }

        // Place tens (rods) in the middle
        for i in 0..<tens {
            let rod = createRod(index: i)
            rod.position = SIMD3<Float>(
                0,
                rodWidth / 2,
                Float(i) * (rodWidth + 0.01) - Float(tens - 1) * (rodWidth + 0.01) / 2
            )
            anchor.addChild(rod)
            tenEntities.append(rod)
        }

        // Place ones (cubes) on the right
        for i in 0..<ones {
            let cube = createCube(index: i)
            let col = i % 5
            let row = i / 5
            cube.position = SIMD3<Float>(
                0.2 + Float(col) * (cubeSize + 0.005),
                cubeSize / 2,
                Float(row) * (cubeSize + 0.005)
            )
            anchor.addChild(cube)
            oneEntities.append(cube)
        }

        // Floating total label
        let totalLabel = createTotalLabel()
        totalLabel.position = SIMD3<Float>(0, 0.15, 0)
        anchor.addChild(totalLabel)

        arView.scene.addAnchor(anchor)
        self.sceneAnchor = anchor

        updateTotalDisplay()
    }

    private func createCube(index: Int) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: cubeSize, cornerRadius: 0.002)
        let material = SimpleMaterial(color: onesColor, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "one_\(index)"
        entity.generateCollisionShapes(recursive: false)
        return entity
    }

    private func createRod(index: Int) -> ModelEntity {
        let mesh = MeshResource.generateBox(
            size: SIMD3<Float>(rodLength, rodWidth, rodWidth),
            cornerRadius: 0.003
        )
        let material = SimpleMaterial(color: tensColor, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "ten_\(index)"
        entity.generateCollisionShapes(recursive: false)
        return entity
    }

    private func createFlat(index: Int) -> ModelEntity {
        let mesh = MeshResource.generateBox(
            size: SIMD3<Float>(flatSize, flatHeight, flatSize),
            cornerRadius: 0.005
        )
        let material = SimpleMaterial(color: hundredsColor, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "hundred_\(index)"
        entity.generateCollisionShapes(recursive: false)
        return entity
    }

    private func createTotalLabel() -> ModelEntity {
        let mesh = MeshResource.generateBox(
            size: SIMD3<Float>(0.1, 0.025, 0.04),
            cornerRadius: 0.005
        )
        let material = SimpleMaterial(color: .systemIndigo, isMetallic: true)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "totalLabel"
        return entity
    }

    // MARK: - Decompose / Compose

    /// Decompose a rod (ten) into 10 unit cubes
    private func decomposeRod(at rodIndex: Int) {
        guard rodIndex < tenEntities.count, let anchor = sceneAnchor else { return }

        let rod = tenEntities[rodIndex]
        let rodPosition = rod.position

        // Remove the rod
        rod.removeFromParent()
        tenEntities.remove(at: rodIndex)
        tens -= 1

        // Create 10 cubes in its place
        for i in 0..<10 {
            let cube = createCube(index: ones + i)
            // Start at rod position, then animate to spread out
            cube.position = rodPosition

            anchor.addChild(cube)
            oneEntities.append(cube)

            // Animate cubes spreading out from rod position
            let targetX = rodPosition.x - rodLength / 2 + Float(i) * (cubeSize + 0.002)
            var transform = cube.transform
            transform.translation = SIMD3<Float>(targetX, cubeSize / 2, rodPosition.z)
            cube.move(to: transform, relativeTo: cube.parent, duration: 0.4)
        }

        ones += 10

        speak("One ten becomes 10 ones!")
        updateTotalDisplay()
    }

    /// Compose 10 unit cubes into a rod
    private func composeCubes() {
        guard oneEntities.count >= 10, let anchor = sceneAnchor else { return }

        // Take the first 10 cubes
        let cubesToCompose = Array(oneEntities.prefix(10))
        let centerPosition = cubesToCompose.reduce(SIMD3<Float>(0, 0, 0)) {
            $0 + $1.position
        } / Float(cubesToCompose.count)

        // Animate cubes toward center, then remove
        for cube in cubesToCompose {
            var transform = cube.transform
            transform.translation = centerPosition
            transform.scale = SIMD3(repeating: 0.1)
            cube.move(to: transform, relativeTo: cube.parent, duration: 0.3)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }

            // Remove the composed cubes
            for cube in cubesToCompose {
                cube.removeFromParent()
            }
            self.oneEntities.removeFirst(10)
            self.ones -= 10

            // Create a new rod
            let rod = self.createRod(index: self.tens)
            rod.position = centerPosition
            rod.position.y = self.rodWidth / 2

            // Scale-in animation
            rod.scale = SIMD3(repeating: 0.1)
            anchor.addChild(rod)
            self.tenEntities.append(rod)
            self.tens += 1

            var rodTransform = rod.transform
            rodTransform.scale = SIMD3(repeating: 1.0)
            rod.move(to: rodTransform, relativeTo: rod.parent, duration: 0.3)

            self.speak("10 ones make one ten!")
            self.updateTotalDisplay()
        }
    }

    private func updateTotalDisplay() {
        let total = hundreds * 100 + tens * 10 + ones
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onTotalUpdate(
                "Total: \(total) = \(self.hundreds) hundreds + \(self.tens) tens + \(self.ones) ones"
            )
        }
    }

    // MARK: - Gesture Handler

    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView = arView else { return }
        let location = recognizer.location(in: arView)

        guard let entity = arView.entity(at: location) else { return }

        // Visual feedback
        var transform = entity.transform
        let originalScale = transform.scale
        transform.scale = originalScale * 1.3
        entity.move(to: transform, relativeTo: entity.parent, duration: 0.12)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            var reset = entity.transform
            reset.scale = originalScale
            entity.move(to: reset, relativeTo: entity.parent, duration: 0.12)
        }

        if entity.name.hasPrefix("ten_") {
            // Decompose rod into 10 cubes
            if let indexStr = entity.name.split(separator: "_").last,
               let index = tenEntities.firstIndex(where: { $0.name == entity.name }) {
                speak("Breaking apart a ten!")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.decomposeRod(at: index)
                }
            }
        } else if entity.name.hasPrefix("one_") {
            // If we have 10+ cubes, compose them
            if oneEntities.count >= 10 {
                speak("Grouping 10 ones into a ten!")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.composeCubes()
                }
            } else {
                speak("\(ones) ones")
            }
        } else if entity.name.hasPrefix("hundred_") {
            speak("\(hundreds) hundreds, that's \(hundreds * 100)")
        }
    }

    // MARK: - Speech

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.1
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}
#endif
