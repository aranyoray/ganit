import SwiftUI
import RealityKit
import ARKit
import AVFoundation

// MARK: - Addition / Subtraction AR Scene

/// V2 Interactive AR scene for addition and subtraction.
/// Two color-coded groups of 3D objects on a detected plane.
/// Drag one group toward the other to merge (add) or split apart (subtract).
struct AdditionScene: View {
    @State private var leftCount: Int
    @State private var rightCount: Int
    @State private var statusMessage = "Point your camera at a flat surface..."
    @State private var arReady = false
    @State private var resultText: String?

    init(left: Int = 3, right: Int = 2) {
        _leftCount = State(initialValue: left)
        _rightCount = State(initialValue: right)
    }

    var body: some View {
        ZStack {
            #if os(iOS)
            AdditionARContainer(
                leftCount: leftCount,
                rightCount: rightCount,
                onReady: { arReady = true },
                onStatusUpdate: { statusMessage = $0 },
                onResult: { resultText = $0 }
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
                    Text("Addition & Subtraction")
                        .font(.title3.bold())
                    Text("Drag the groups together to add, or apart to subtract!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let result = resultText {
                        Text(result)
                            .font(.title2.bold())
                            .foregroundColor(.green)
                            .transition(.scale)

                        Button("Next Example") {
                            leftCount = Int.random(in: 1...5)
                            rightCount = Int.random(in: 1...5)
                            resultText = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding()
            }
        }
        .navigationTitle("AR Addition")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - iOS AR Container

#if os(iOS)
struct AdditionARContainer: UIViewRepresentable {
    let leftCount: Int
    let rightCount: Int
    var onReady: () -> Void
    var onStatusUpdate: (String) -> Void
    var onResult: (String) -> Void

    func makeUIView(context: Context) -> ARView {
        context.coordinator.createARView(enablePan: true)
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        let coord = context.coordinator
        if coord.leftCount != leftCount || coord.rightCount != rightCount {
            coord.updateCounts(left: leftCount, right: rightCount)
        }
    }

    func makeCoordinator() -> AdditionCoordinator {
        AdditionCoordinator(
            leftCount: leftCount,
            rightCount: rightCount,
            onReady: onReady,
            onStatusUpdate: onStatusUpdate,
            onResult: onResult
        )
    }
}

// MARK: - Addition Coordinator

class AdditionCoordinator: ARSceneCoordinator {
    var leftCount: Int
    var rightCount: Int
    var onResult: (String) -> Void

    // Entity tracking
    private var leftGroupAnchor: AnchorEntity?
    private var rightGroupAnchor: AnchorEntity?
    private var leftEntities: [ModelEntity] = []
    private var rightEntities: [ModelEntity] = []
    private var resultLabel: ModelEntity?
    private var isMerged = false

    // Drag tracking
    private var draggedGroup: String? // "left" or "right"
    private var dragStartPosition: SIMD3<Float>?

    // Colors
    private let warmColors: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow
    ]
    private let coolColors: [UIColor] = [
        .systemBlue, .systemCyan, .systemTeal
    ]

    init(leftCount: Int, rightCount: Int,
         onReady: @escaping () -> Void,
         onStatusUpdate: @escaping (String) -> Void,
         onResult: @escaping (String) -> Void) {
        self.leftCount = leftCount
        self.rightCount = rightCount
        self.onResult = onResult
        super.init(onReady: onReady, onStatusUpdate: onStatusUpdate)
    }

    // MARK: - Scene Construction

    func updateCounts(left: Int, right: Int) {
        leftCount = left
        rightCount = right
        // Clean up old content
        leftGroupAnchor?.removeFromParent()
        rightGroupAnchor?.removeFromParent()
        leftEntities.removeAll()
        rightEntities.removeAll()
        isMerged = false
        // Re-place with new counts if we already have a plane
        if hasPlacedContent, let arView = arView,
           let anchor = arView.session.currentFrame?.anchors.compactMap({ $0 as? ARPlaneAnchor }).first {
            placeGroups(on: anchor)
            speak("Let's add \(leftCount) and \(rightCount) together!")
        }
    }

    override func placeContent(on planeAnchor: ARPlaneAnchor, in session: ARSession) {
        placeGroups(on: planeAnchor)
        speak("Let's add \(leftCount) and \(rightCount) together!")
    }

    private func placeGroups(on anchor: ARPlaneAnchor) {
        guard let arView = arView else { return }

        let planePosition = SIMD3<Float>(
            anchor.center.x,
            0,
            anchor.center.z
        )

        // Left group anchor - warm colors
        let leftAnchor = AnchorEntity(plane: .horizontal)
        leftAnchor.name = "leftGroup"
        leftAnchor.position = planePosition + SIMD3<Float>(-0.15, 0, 0)

        for i in 0..<leftCount {
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.025),
                materials: [SimpleMaterial(
                    color: warmColors[i % warmColors.count],
                    isMetallic: false
                )]
            )
            sphere.name = "left_\(i)"
            sphere.generateCollisionShapes(recursive: false)

            // Arrange in a small cluster
            let angle = Float(i) * (2 * .pi / Float(leftCount))
            let radius: Float = leftCount > 1 ? 0.04 : 0
            sphere.position = SIMD3<Float>(
                cos(angle) * radius,
                0.025,
                sin(angle) * radius
            )
            leftAnchor.addChild(sphere)
            leftEntities.append(sphere)
        }

        arView.scene.addAnchor(leftAnchor)
        self.leftGroupAnchor = leftAnchor

        // Right group anchor - cool colors
        let rightAnchor = AnchorEntity(plane: .horizontal)
        rightAnchor.name = "rightGroup"
        rightAnchor.position = planePosition + SIMD3<Float>(0.15, 0, 0)

        for i in 0..<rightCount {
            let cube = ModelEntity(
                mesh: .generateBox(size: 0.04, cornerRadius: 0.005),
                materials: [SimpleMaterial(
                    color: coolColors[i % coolColors.count],
                    isMetallic: false
                )]
            )
            cube.name = "right_\(i)"
            cube.generateCollisionShapes(recursive: false)

            let angle = Float(i) * (2 * .pi / Float(rightCount))
            let radius: Float = rightCount > 1 ? 0.04 : 0
            cube.position = SIMD3<Float>(
                cos(angle) * radius,
                0.025,
                sin(angle) * radius
            )
            rightAnchor.addChild(cube)
            rightEntities.append(cube)
        }

        arView.scene.addAnchor(rightAnchor)
        self.rightGroupAnchor = rightAnchor
    }

    // MARK: - Gesture Handlers

    override func handleEntityTap(_ entity: Entity, in arView: ARView) {
        // Speak the number if tapped on a group member
        if entity.name.hasPrefix("left_") {
            speak("\(leftCount)")
        } else if entity.name.hasPrefix("right_") {
            speak("\(rightCount)")
        }
    }

    override func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        guard let arView = arView else { return }

        switch recognizer.state {
        case .began:
            let location = recognizer.location(in: arView)
            if let entity = arView.entity(at: location) {
                if entity.name.hasPrefix("left_") {
                    draggedGroup = "left"
                    dragStartPosition = leftGroupAnchor?.position
                } else if entity.name.hasPrefix("right_") {
                    draggedGroup = "right"
                    dragStartPosition = rightGroupAnchor?.position
                }
            }

        case .changed:
            let translation = recognizer.translation(in: arView)
            let scaleFactor: Float = 0.001

            if draggedGroup == "left", let anchor = leftGroupAnchor,
               let start = dragStartPosition {
                anchor.position = SIMD3<Float>(
                    start.x + Float(translation.x) * scaleFactor,
                    start.y,
                    start.z + Float(translation.y) * scaleFactor
                )
            } else if draggedGroup == "right", let anchor = rightGroupAnchor,
                      let start = dragStartPosition {
                anchor.position = SIMD3<Float>(
                    start.x + Float(translation.x) * scaleFactor,
                    start.y,
                    start.z + Float(translation.y) * scaleFactor
                )
            }

            // Check proximity for merge
            checkMergeOrSplit()

        case .ended, .cancelled:
            draggedGroup = nil
            dragStartPosition = nil

        default:
            break
        }
    }

    // MARK: - Merge / Split Logic

    private func checkMergeOrSplit() {
        guard let leftPos = leftGroupAnchor?.position,
              let rightPos = rightGroupAnchor?.position else { return }

        let distance = simd_distance(leftPos, rightPos)

        if distance < 0.08 && !isMerged {
            performMerge()
        } else if distance > 0.25 && isMerged {
            performSplit()
        }
    }

    private func performMerge() {
        isMerged = true
        let sum = leftCount + rightCount

        // Animate right group entities toward left group center
        for entity in rightEntities {
            var transform = entity.transform
            transform.translation = SIMD3<Float>(0, 0.025, 0)
            entity.move(to: transform, relativeTo: entity.parent, duration: 0.4)
        }

        // Particle-like effect: scale burst on all entities
        let allEntities = leftEntities + rightEntities
        for entity in allEntities {
            var burst = entity.transform
            burst.scale = SIMD3(repeating: 1.5)
            entity.move(to: burst, relativeTo: entity.parent, duration: 0.2)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                var settle = entity.transform
                settle.scale = SIMD3(repeating: 1.0)
                entity.move(to: settle, relativeTo: entity.parent, duration: 0.2)
            }
        }

        showResultLabel(number: sum)
        speak("\(leftCount) plus \(rightCount) equals \(sum)!")

        DispatchQueue.main.async { [weak self] in
            self?.onResult("\(self?.leftCount ?? 0) + \(self?.rightCount ?? 0) = \(sum)")
        }
    }

    private func performSplit() {
        isMerged = false

        for (i, entity) in rightEntities.enumerated() {
            let angle = Float(i) * (2 * .pi / Float(rightCount))
            let radius: Float = rightCount > 1 ? 0.04 : 0
            var transform = entity.transform
            transform.translation = SIMD3<Float>(
                cos(angle) * radius,
                0.025,
                sin(angle) * radius
            )
            entity.move(to: transform, relativeTo: entity.parent, duration: 0.4)
        }

        resultLabel?.removeFromParent()
        resultLabel = nil

        let difference = abs(leftCount - rightCount)
        speak("\(leftCount) minus \(rightCount) equals \(difference)!")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onResult("\(self.leftCount) - \(self.rightCount) = \(difference)")
        }
    }

    private func showResultLabel(number: Int) {
        guard let leftAnchor = leftGroupAnchor else { return }

        resultLabel?.removeFromParent()

        let textMesh = MeshResource.generateBox(
            size: SIMD3<Float>(0.06, 0.02, 0.005),
            cornerRadius: 0.003
        )
        let material = SimpleMaterial(color: .systemGreen, isMetallic: true)
        let label = ModelEntity(mesh: textMesh, materials: [material])
        label.name = "result_\(number)"
        label.position = SIMD3<Float>(0, 0.12, 0)

        leftAnchor.addChild(label)
        resultLabel = label

        let startPosition = SIMD3<Float>(0, 0.05, 0)
        label.position = startPosition
        var endTransform = label.transform
        endTransform.translation = SIMD3<Float>(0, 0.12, 0)
        label.move(to: endTransform, relativeTo: label.parent, duration: 0.5)
    }
}
#endif
