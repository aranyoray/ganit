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

                        Button("Next Number") {
                            targetNumber = Int.random(in: 11...99)
                            currentTotal = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
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
        context.coordinator.createARView()
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if context.coordinator.targetNumber != targetNumber {
            context.coordinator.updateTarget(targetNumber)
        }
    }

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

class PlaceValueCoordinator: ARSceneCoordinator {
    var targetNumber: Int
    var onTotalUpdate: (String) -> Void

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
        self.onTotalUpdate = onTotalUpdate
        super.init(onReady: onReady, onStatusUpdate: onStatusUpdate)
    }

    // MARK: - Scene Construction

    func updateTarget(_ number: Int) {
        targetNumber = number
        placeNumber(number)
        speak("How many tens are in \(number)?")
    }

    override func placeContent(on planeAnchor: ARPlaneAnchor, in session: ARSession) {
        placeNumber(targetNumber)
        let tensInNumber = (targetNumber / 10) % 10
        speak("How many tens are in \(targetNumber)? There are \(tensInNumber) tens!")
    }

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

    private func decomposeRod(at rodIndex: Int) {
        guard rodIndex < tenEntities.count, let anchor = sceneAnchor else { return }

        let rod = tenEntities[rodIndex]
        let rodPosition = rod.position

        rod.removeFromParent()
        tenEntities.remove(at: rodIndex)
        tens -= 1

        for i in 0..<10 {
            let cube = createCube(index: ones + i)
            cube.position = rodPosition

            anchor.addChild(cube)
            oneEntities.append(cube)

            let targetX = rodPosition.x - rodLength / 2 + Float(i) * (cubeSize + 0.002)
            var transform = cube.transform
            transform.translation = SIMD3<Float>(targetX, cubeSize / 2, rodPosition.z)
            cube.move(to: transform, relativeTo: cube.parent, duration: 0.4)
        }

        ones += 10
        updateTotalDisplay()
    }

    private func composeCubes() {
        guard oneEntities.count >= 10, let anchor = sceneAnchor else { return }

        let cubesToCompose = Array(oneEntities.prefix(10))
        let centerPosition = cubesToCompose.reduce(SIMD3<Float>(0, 0, 0)) {
            $0 + $1.position
        } / Float(cubesToCompose.count)

        for cube in cubesToCompose {
            var transform = cube.transform
            transform.translation = centerPosition
            transform.scale = SIMD3(repeating: 0.1)
            cube.move(to: transform, relativeTo: cube.parent, duration: 0.3)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }

            for cube in cubesToCompose {
                cube.removeFromParent()
            }
            self.oneEntities.removeFirst(10)
            self.ones -= 10

            let rod = self.createRod(index: self.tens)
            rod.position = centerPosition
            rod.position.y = self.rodWidth / 2

            rod.scale = SIMD3(repeating: 0.1)
            anchor.addChild(rod)
            self.tenEntities.append(rod)
            self.tens += 1

            var rodTransform = rod.transform
            rodTransform.scale = SIMD3(repeating: 1.0)
            rod.move(to: rodTransform, relativeTo: rod.parent, duration: 0.3)

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

    override func handleEntityTap(_ entity: Entity, in arView: ARView) {
        // Prevent overlapping speech
        guard !synthesizer.isSpeaking else { return }

        if entity.name.hasPrefix("ten_") {
            if let index = tenEntities.firstIndex(where: { $0.name == entity.name }) {
                speak("Breaking apart a ten!")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.decomposeRod(at: index)
                }
            }
        } else if entity.name.hasPrefix("one_") {
            if oneEntities.count >= 10 {
                speak("Grouping 10 ones into a ten!")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.composeCubes()
                }
            } else {
                speak("\(ones) ones")
            }
        } else if entity.name.hasPrefix("hundred_") {
            speak("\(hundreds) hundreds, that's \(hundreds * 100)")
        }
    }
}
#endif
