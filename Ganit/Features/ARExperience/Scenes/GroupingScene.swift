import SwiftUI
import RealityKit
import ARKit
import AVFoundation

// MARK: - Grouping Scene

/// V3 spatial grouping: objects scattered on a detected plane.
/// Voice instruction tells the child how many to put in the basket.
/// User drags objects into the basket using pan gesture.
struct GroupingScene: View {
    @State private var arReady = false
    @State private var statusMessage = "Point your camera at a flat surface..."
    @State private var collectedCount: Int = 0
    @State private var targetCount: Int = 0
    @State private var showCelebration = false

    var body: some View {
        ZStack {
            #if os(iOS)
            GroupingARContainer(
                onReady: { target in
                    arReady = true
                    targetCount = target
                },
                onStatusUpdate: { statusMessage = $0 },
                onObjectCollected: { count in
                    collectedCount = count
                },
                onTargetReached: {
                    showCelebration = true
                }
            )
            .edgesIgnoringSafeArea(.all)
            #else
            Text("AR Grouping is only available on iOS devices with ARKit support.")
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

                if arReady {
                    VStack(spacing: 8) {
                        if showCelebration {
                            Text("Great job!")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.teal)

                            Text("You collected all \(targetCount)!")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(collectedCount) / \(targetCount)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("Drag the apples into the blue basket!")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding()
                }
            }

            if showCelebration {
                celebrationOverlay
            }
        }
        .navigationTitle("Grouping")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var celebrationOverlay: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "star.fill")
                .font(.system(size: 72))
                .foregroundColor(.yellow)
            Text("You did it!")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Button("Play Again") {
                showCelebration = false
                collectedCount = 0
                // The AR container will reset on next layout pass
            }
            .font(.system(size: 20, weight: .semibold))
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(Color.white)
            .foregroundColor(.teal)
            .cornerRadius(16)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.teal.opacity(0.7))
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Grouping AR Container (iOS)

#if os(iOS)
struct GroupingARContainer: UIViewRepresentable {
    var onReady: (Int) -> Void
    var onStatusUpdate: (String) -> Void
    var onObjectCollected: (Int) -> Void
    var onTargetReached: () -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic

        arView.session.run(config)
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView

        // Pan gesture for dragging objects
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        arView.addGestureRecognizer(panGesture)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onReady: onReady,
            onStatusUpdate: onStatusUpdate,
            onObjectCollected: onObjectCollected,
            onTargetReached: onTargetReached
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        var hasPlacedContent = false

        var onReady: (Int) -> Void
        var onStatusUpdate: (String) -> Void
        var onObjectCollected: (Int) -> Void
        var onTargetReached: () -> Void

        private let synthesizer = AVSpeechSynthesizer()
        private var objectEntities: [ModelEntity] = []
        private var basketEntity: ModelEntity?
        private var basketDropZone: SIMD3<Float> = .zero
        private var draggedEntity: ModelEntity?
        private var dragStartPosition: SIMD3<Float> = .zero
        private var collectedCount = 0
        private let targetCount: Int
        private let basketDropRadius: Float = 0.15

        init(
            onReady: @escaping (Int) -> Void,
            onStatusUpdate: @escaping (String) -> Void,
            onObjectCollected: @escaping (Int) -> Void,
            onTargetReached: @escaping () -> Void
        ) {
            self.targetCount = Int.random(in: 2...5)
            self.onReady = onReady
            self.onStatusUpdate = onStatusUpdate
            self.onObjectCollected = onObjectCollected
            self.onTargetReached = onTargetReached
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard !hasPlacedContent, let arView = arView else { return }

            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor,
                   planeAnchor.alignment == .horizontal,
                   planeAnchor.extent.x > 0.3, planeAnchor.extent.z > 0.3 {
                    hasPlacedContent = true
                    onStatusUpdate("Surface found! Setting up...")
                    placeScene(on: planeAnchor, in: arView)
                    onReady(targetCount)
                    speakInstruction()
                    break
                }
            }
        }

        // MARK: - Scene Setup

        private func placeScene(on anchor: ARPlaneAnchor, in arView: ARView) {
            let anchorEntity = AnchorEntity(anchor: anchor)

            // Place basket on the left side
            let basketMesh = MeshResource.generateBox(
                width: 0.2, height: 0.1, depth: 0.2,
                cornerRadius: 0.02
            )
            let basketMaterial = SimpleMaterial(
                color: .systemBlue.withAlphaComponent(0.7),
                isMetallic: false
            )
            let basket = ModelEntity(mesh: basketMesh, materials: [basketMaterial])
            basket.position = SIMD3(-0.4, 0.05, 0)
            basket.name = "basket"
            basket.generateCollisionShapes(recursive: false)
            anchorEntity.addChild(basket)
            basketEntity = basket
            basketDropZone = basket.position

            // Scatter apple-like objects on the right side
            let totalObjects = targetCount + 2 // A few extras for variety
            for i in 0..<totalObjects {
                let objectMesh = MeshResource.generateSphere(radius: 0.04)
                let objectMaterial = SimpleMaterial(
                    color: .systemRed,
                    isMetallic: false
                )
                let object = ModelEntity(mesh: objectMesh, materials: [objectMaterial])

                // Scatter on the right half
                let x = Float.random(in: 0.1...0.5)
                let z = Float.random(in: -0.3...0.3)
                object.position = SIMD3(x, 0.04, z)
                object.name = "apple_\(i)"
                object.generateCollisionShapes(recursive: false)

                anchorEntity.addChild(object)
                objectEntities.append(object)
            }

            arView.scene.addAnchor(anchorEntity)
        }

        private func speakInstruction() {
            let text = "Put \(targetCount) apples in the blue basket!"
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = 0.4
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(utterance)
        }

        // MARK: - Drag Handling

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let arView = recognizer.view as? ARView else { return }
            let location = recognizer.location(in: arView)

            switch recognizer.state {
            case .began:
                // Find the entity under the touch
                if let entity = arView.entity(at: location) as? ModelEntity,
                   entity.name.hasPrefix("apple_") {
                    draggedEntity = entity
                    dragStartPosition = entity.position
                    // Scale up slightly to show it is being dragged
                    var transform = entity.transform
                    transform.scale = SIMD3(repeating: 1.3)
                    entity.move(to: transform, relativeTo: entity.parent, duration: 0.1)
                }

            case .changed:
                guard let entity = draggedEntity else { return }
                // Raycast to find position on the plane
                let results = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal)
                if let result = results.first {
                    let worldPosition = result.worldTransform.columns.3
                    // Convert to local coordinates relative to parent
                    if let parent = entity.parent {
                        let localPosition = parent.convert(
                            position: SIMD3(worldPosition.x, worldPosition.y + 0.04, worldPosition.z),
                            from: nil
                        )
                        entity.position = localPosition
                    }
                }

            case .ended, .cancelled:
                guard let entity = draggedEntity else { return }

                // Reset scale
                var transform = entity.transform
                transform.scale = SIMD3(repeating: 1.0)
                entity.move(to: transform, relativeTo: entity.parent, duration: 0.1)

                // Check if dropped in basket zone (collision detection)
                let distance = simd_distance(
                    SIMD2(entity.position.x, entity.position.z),
                    SIMD2(basketDropZone.x, basketDropZone.z)
                )

                if distance < basketDropRadius {
                    // Successfully dropped in basket
                    objectCollected(entity)
                }

                draggedEntity = nil

            default:
                break
            }
        }

        private func objectCollected(_ entity: ModelEntity) {
            guard collectedCount < targetCount else { return }

            collectedCount += 1

            // Hide the collected object (move it into the basket)
            entity.position = basketDropZone
            var transform = entity.transform
            transform.scale = SIMD3(repeating: 0.3)
            entity.move(to: transform, relativeTo: entity.parent, duration: 0.2)

            // Remove from draggable list
            objectEntities.removeAll { $0 === entity }

            // Speak the count
            let utterance = AVSpeechUtterance(string: "\(collectedCount)")
            utterance.rate = 0.4
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(utterance)

            DispatchQueue.main.async {
                self.onObjectCollected(self.collectedCount)
            }

            // Check success
            if collectedCount >= targetCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.celebrate()
                }
            }
        }

        private func celebrate() {
            let utterance = AVSpeechUtterance(string: "Great job! You collected all \(targetCount)!")
            utterance.rate = 0.4
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(utterance)

            DispatchQueue.main.async {
                self.onTargetReached()
            }
        }
    }
}
#endif
