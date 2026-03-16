import SwiftUI
import RealityKit
import ARKit
import AVFoundation

// MARK: - Number Playground AR Scene

/// V2 Free-play AR scene where children explore numbers in 3D space.
/// No quiz pressure. Spawn, stack, group, break apart, and count number blocks.
struct NumberPlaygroundScene: View {
    @State private var statusMessage = "Point your camera at a flat surface..."
    @State private var arReady = false
    @State private var blockCount = 0
    @State private var tappedTotal = 0

    var body: some View {
        ZStack {
            #if os(iOS)
            PlaygroundARContainer(
                onReady: { arReady = true },
                onStatusUpdate: { statusMessage = $0 },
                onBlockCountChange: { blockCount = $0 },
                onTappedTotalChange: { tappedTotal = $0 }
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
                    Text("Number Playground")
                        .font(.title3.bold())
                    Text("Tap empty space to add blocks. Tap blocks to count!")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 20) {
                        VStack {
                            Text("\(blockCount)")
                                .font(.title.bold())
                                .foregroundColor(.blue)
                            Text("Blocks")
                                .font(.caption2)
                        }
                        VStack {
                            Text("\(tappedTotal)")
                                .font(.title.bold())
                                .foregroundColor(.purple)
                            Text("Counted")
                                .font(.caption2)
                        }
                    }

                    // Color legend
                    HStack(spacing: 8) {
                        LegendItem(colors: [.systemGreen], label: "1-3")
                        LegendItem(colors: [.systemBlue], label: "4-6")
                        LegendItem(colors: [.systemPurple], label: "7-9")
                        LegendItem(colors: [.init(red: 1, green: 0.84, blue: 0, alpha: 1)], label: "10+")
                    }
                    .font(.caption2)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal)

                // Reset button
                Button(action: {
                    NotificationCenter.default.post(
                        name: .playgroundReset, object: nil
                    )
                    blockCount = 0
                    tappedTotal = 0
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset")
                    }
                    .font(.callout.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("AR Playground")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Small legend item for color coding.
private struct LegendItem: View {
    let colors: [UIColor]
    let label: String

    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(Color(colors[0]))
                .frame(width: 8, height: 8)
            Text(label)
        }
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
    var onTappedTotalChange: (Int) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = context.coordinator.createARView(enablePan: true)

        // Listen for reset
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
            onBlockCountChange: onBlockCountChange,
            onTappedTotalChange: onTappedTotalChange
        )
    }
}

// MARK: - Playground Coordinator

class PlaygroundCoordinator: ARSceneCoordinator {
    var onBlockCountChange: (Int) -> Void
    var onTappedTotalChange: (Int) -> Void

    // Scene
    private var playgroundAnchor: AnchorEntity?
    private var blockEntities: [ModelEntity] = []
    private var tappedCount = 0
    private var nextBlockID = 0

    // Drag state
    private var draggedEntity: ModelEntity?
    private var dragStartPosition: SIMD3<Float>?

    // Block sizing
    private let blockSize: Float = 0.035

    // Color coding by quantity
    private func blockColor(for totalCount: Int) -> UIColor {
        switch totalCount {
        case 1...3:   return .systemGreen
        case 4...6:   return .systemBlue
        case 7...9:   return .systemPurple
        default:      return UIColor(red: 1, green: 0.84, blue: 0, alpha: 1) // gold
        }
    }

    init(onReady: @escaping () -> Void,
         onStatusUpdate: @escaping (String) -> Void,
         onBlockCountChange: @escaping (Int) -> Void,
         onTappedTotalChange: @escaping (Int) -> Void) {
        self.onBlockCountChange = onBlockCountChange
        self.onTappedTotalChange = onTappedTotalChange
        super.init(onReady: onReady, onStatusUpdate: onStatusUpdate)
    }


    // MARK: - Scene Setup

    override func placeContent(on planeAnchor: ARPlaneAnchor, in session: ARSession) {
        setupPlayground()
        speak("Welcome to the number playground! Tap anywhere to create blocks.")
    }

    private func setupPlayground() {
        guard let arView = arView else { return }

        let anchor = AnchorEntity(plane: .horizontal)
        anchor.name = "playground"
        arView.scene.addAnchor(anchor)
        self.playgroundAnchor = anchor
    }

    // MARK: - Block Management

    private func spawnBlock(at position: SIMD3<Float>) {
        guard let anchor = playgroundAnchor else { return }

        let id = nextBlockID
        nextBlockID += 1
        let totalAfterSpawn = blockEntities.count + 1

        let color = blockColor(for: totalAfterSpawn)
        let mesh = MeshResource.generateBox(
            size: blockSize,
            cornerRadius: 0.004
        )
        let material = SimpleMaterial(color: color, isMetallic: false)
        let block = ModelEntity(mesh: mesh, materials: [material])
        block.name = "block_\(id)"
        block.generateCollisionShapes(recursive: false)

        block.position = position
        block.position.y = blockSize / 2
        block.scale = SIMD3(repeating: 0.01)

        anchor.addChild(block)
        blockEntities.append(block)

        var transform = block.transform
        transform.scale = SIMD3(repeating: 1.0)
        block.move(to: transform, relativeTo: block.parent, duration: 0.25)

        updateAllBlockColors()

        speak("\(totalAfterSpawn)")

        DispatchQueue.main.async { [weak self] in
            self?.onBlockCountChange(totalAfterSpawn)
        }
    }

    private func updateAllBlockColors() {
        let total = blockEntities.count
        let color = blockColor(for: total)
        let material = SimpleMaterial(color: color, isMetallic: false)

        for block in blockEntities {
            block.model?.materials = [material]
        }
    }

    @objc func resetAll() {
        for block in blockEntities {
            var transform = block.transform
            transform.scale = SIMD3(repeating: 0.01)
            block.move(to: transform, relativeTo: block.parent, duration: 0.2)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            for block in self.blockEntities {
                block.removeFromParent()
            }
            self.blockEntities.removeAll()
            self.tappedCount = 0
            self.nextBlockID = 0

            self.onBlockCountChange(0)
            self.onTappedTotalChange(0)
        }

        speak("All clear! Tap to start again.")
    }

    // MARK: - Gesture Handlers

    override func handleEntityTap(_ entity: Entity, in arView: ARView) {
        if entity.name.hasPrefix("block_") {
            tappedCount += 1
            speak("\(tappedCount)")

            DispatchQueue.main.async { [weak self] in
                self?.onTappedTotalChange(self?.tappedCount ?? 0)
            }
            return
        }

        // Tapped empty space: spawn via the overridden handleTap
        // (this won't be called for empty space since entity is nil there)
    }

    /// Override the base tap handler to also handle taps on empty space (raycast spawning).
    @objc override func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView = arView else { return }
        let location = recognizer.location(in: arView)

        // Check if tapped on an existing block
        if let entity = arView.entity(at: location),
           entity.name.hasPrefix("block_") {
            // Count this block
            tappedCount += 1

            // Visual feedback: bounce
            animateTapFeedback(on: entity, scale: 1.4)

            speak("\(tappedCount)")

            DispatchQueue.main.async { [weak self] in
                self?.onTappedTotalChange(self?.tappedCount ?? 0)
            }
            return
        }

        // Tapped empty space: spawn a new block via raycast
        let results = arView.raycast(
            from: location,
            allowing: .existingPlaneGeometry,
            alignment: .horizontal
        )

        if let firstResult = results.first {
            let worldPosition = firstResult.worldTransform.columns.3
            let localPosition = SIMD3<Float>(worldPosition.x, 0, worldPosition.z)

            if let anchor = playgroundAnchor {
                let anchorWorldPos = anchor.position(relativeTo: nil)
                let relativePos = localPosition - anchorWorldPos
                spawnBlock(at: relativePos)
            } else {
                spawnBlock(at: localPosition)
            }
        }
    }

    override func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        guard let arView = arView else { return }

        switch recognizer.state {
        case .began:
            let location = recognizer.location(in: arView)
            if let entity = arView.entity(at: location) as? ModelEntity,
               entity.name.hasPrefix("block_") {
                draggedEntity = entity
                dragStartPosition = entity.position
                var transform = entity.transform
                transform.translation.y += 0.02
                entity.move(to: transform, relativeTo: entity.parent, duration: 0.1)
            }

        case .changed:
            guard let entity = draggedEntity,
                  let start = dragStartPosition else { return }

            let translation = recognizer.translation(in: arView)
            let scaleFactor: Float = 0.001

            entity.position = SIMD3<Float>(
                start.x + Float(translation.x) * scaleFactor,
                entity.position.y,
                start.z + Float(translation.y) * scaleFactor
            )

            checkStacking(for: entity)

        case .ended, .cancelled:
            if let entity = draggedEntity {
                var transform = entity.transform
                transform.translation.y = blockSize / 2
                entity.move(to: transform, relativeTo: entity.parent, duration: 0.15)
            }
            draggedEntity = nil
            dragStartPosition = nil

        default:
            break
        }
    }

    private func checkStacking(for entity: ModelEntity) {
        for other in blockEntities {
            guard other.name != entity.name else { continue }

            let dx = entity.position.x - other.position.x
            let dz = entity.position.z - other.position.z
            let horizontalDistance = sqrt(dx * dx + dz * dz)

            if horizontalDistance < blockSize * 0.6 {
                entity.position.x = other.position.x
                entity.position.z = other.position.z
                entity.position.y = other.position.y + blockSize + 0.002
                break
            }
        }
    }
}
#endif
