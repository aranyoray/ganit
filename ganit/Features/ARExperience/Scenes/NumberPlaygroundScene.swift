import SwiftUI
import RealityKit
import ARKit
import AVFoundation

// MARK: - Number Playground AR Scene

/// Goal-based AR scene: "Build the number N!"
/// Child taps to spawn blocks until they reach the target number.
/// Correct count triggers celebration + next challenge.
struct NumberPlaygroundScene: View {
    @State private var statusMessage = "Point your camera at a flat surface..."
    @State private var arReady = false
    @State private var blockCount = 0
    @State private var targetNumber = Int.random(in: 3...8)
    @State private var showSuccess = false
    @State private var score = 0

    var body: some View {
        ZStack {
            #if os(iOS)
            PlaygroundARContainer(
                onReady: { arReady = true },
                onStatusUpdate: { statusMessage = $0 },
                onBlockCountChange: { count in
                    blockCount = count
                    if count == targetNumber && !showSuccess {
                        showSuccess = true
                        score += 1
                    }
                }
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

                if showSuccess {
                    VStack(spacing: 8) {
                        Text("You built \(targetNumber)!")
                            .font(.title2.bold())
                            .foregroundColor(.green)
                        Text("Score: \(score)")
                            .font(.headline)
                            .foregroundColor(.orange)

                        Button("Next Challenge") {
                            showSuccess = false
                            targetNumber = Int.random(in: 3...9)
                            blockCount = 0
                            NotificationCenter.default.post(
                                name: .playgroundReset, object: nil
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding()
                } else {
                    VStack(spacing: 8) {
                        Text("Build the number:")
                            .font(.headline)
                        Text("\(targetNumber)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.blue)

                        // Progress indicator
                        HStack(spacing: 4) {
                            ForEach(0..<targetNumber, id: \.self) { i in
                                Circle()
                                    .fill(i < blockCount ? Color.green : Color.gray.opacity(0.3))
                                    .frame(width: 16, height: 16)
                            }
                        }

                        Text("Tap the surface to add blocks")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if blockCount > targetNumber {
                            Text("Too many! Tap Reset to try again.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        HStack(spacing: 16) {
                            Text("\(blockCount) blocks")
                                .font(.subheadline.bold())
                                .foregroundColor(blockCount == targetNumber ? .green : .primary)

                            Button("Reset") {
                                NotificationCenter.default.post(
                                    name: .playgroundReset, object: nil
                                )
                                blockCount = 0
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .navigationTitle("AR Number Builder")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Notification for reset

extension Notification.Name {
    static let playgroundReset = Notification.Name("playgroundReset")
}

// MARK: - iOS AR Container

#if os(iOS)
struct PlaygroundARContainer: UIViewRepresentable {
    var onReady: () -> Void
    var onStatusUpdate: (String) -> Void
    var onBlockCountChange: (Int) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = context.coordinator.createARView(enablePan: false)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(PlaygroundCoordinator.resetAll),
            name: .playgroundReset,
            object: nil
        )

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> PlaygroundCoordinator {
        PlaygroundCoordinator(
            onReady: onReady,
            onStatusUpdate: onStatusUpdate,
            onBlockCountChange: onBlockCountChange
        )
    }
}

// MARK: - Playground Coordinator

class PlaygroundCoordinator: ARSceneCoordinator {
    var onBlockCountChange: (Int) -> Void

    private var playgroundAnchor: AnchorEntity?
    private var blockEntities: [ModelEntity] = []
    private var nextBlockID = 0
    private let blockSize: Float = 0.04

    private let blockColors: [UIColor] = [
        .systemBlue, .systemGreen, .systemOrange, .systemPurple,
        .systemPink, .systemTeal, .systemYellow, .systemRed, .systemCyan
    ]

    init(onReady: @escaping () -> Void,
         onStatusUpdate: @escaping (String) -> Void,
         onBlockCountChange: @escaping (Int) -> Void) {
        self.onBlockCountChange = onBlockCountChange
        super.init(onReady: onReady, onStatusUpdate: onStatusUpdate)
    }

    override func placeContent(on planeAnchor: ARPlaneAnchor, in session: ARSession) {
        guard let arView = arView else { return }
        let anchor = AnchorEntity(plane: .horizontal)
        anchor.name = "playground"
        arView.scene.addAnchor(anchor)
        self.playgroundAnchor = anchor
        speak("Tap the surface to build your number!")
    }

    private func spawnBlock(at position: SIMD3<Float>) {
        guard let anchor = playgroundAnchor else { return }

        let id = nextBlockID
        nextBlockID += 1
        let count = blockEntities.count + 1

        let color = blockColors[(count - 1) % blockColors.count]
        let mesh = MeshResource.generateBox(size: blockSize, cornerRadius: 0.005)
        let material = SimpleMaterial(color: color, isMetallic: false)
        let block = ModelEntity(mesh: mesh, materials: [material])
        block.name = "block_\(id)"
        block.generateCollisionShapes(recursive: false)

        // Arrange in a neat row
        let col = (count - 1) % 5
        let row = (count - 1) / 5
        block.position = SIMD3<Float>(
            Float(col) * (blockSize + 0.01) - 0.1,
            blockSize / 2,
            Float(row) * (blockSize + 0.01)
        )
        block.scale = SIMD3(repeating: 0.01)

        anchor.addChild(block)
        blockEntities.append(block)

        var transform = block.transform
        transform.scale = SIMD3(repeating: 1.0)
        block.move(to: transform, relativeTo: block.parent, duration: 0.2)

        if !synthesizer.isSpeaking {
            speak("\(count)")
        }

        DispatchQueue.main.async { [weak self] in
            self?.onBlockCountChange(count)
        }
    }

    @objc func resetAll() {
        for block in blockEntities {
            block.removeFromParent()
        }
        blockEntities.removeAll()
        nextBlockID = 0

        DispatchQueue.main.async { [weak self] in
            self?.onBlockCountChange(0)
        }
    }

    @objc override func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView = arView else { return }
        let location = recognizer.location(in: arView)

        // If tapped on an existing block, just bounce it
        if let entity = arView.entity(at: location),
           entity.name.hasPrefix("block_") {
            animateTapFeedback(on: entity, scale: 1.3)
            return
        }

        // Tapped empty space: spawn a block
        spawnBlock(at: SIMD3<Float>(0, 0, 0))
    }
}
#endif
