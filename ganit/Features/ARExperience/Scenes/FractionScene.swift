import SwiftUI
import RealityKit
import ARKit
import AVFoundation

// MARK: - Fraction AR Scene

/// V2 Interactive AR scene for learning fractions.
/// A 3D circular disc (pizza/pie) placed on a detected plane.
/// Swipe across to slice it; pieces separate and can be recombined.
struct FractionScene: View {
    @State private var targetDenominator: Int
    @State private var statusMessage = "Point your camera at a flat surface..."
    @State private var arReady = false
    @State private var sliceInfo: String?

    init(denominator: Int = 4) {
        _targetDenominator = State(initialValue: denominator)
    }

    var body: some View {
        ZStack {
            #if os(iOS)
            FractionARContainer(
                targetDenominator: targetDenominator,
                onReady: { arReady = true },
                onStatusUpdate: { statusMessage = $0 },
                onSliceUpdate: { sliceInfo = $0 }
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
                    Text("Fractions")
                        .font(.title3.bold())
                    Text("Swipe across the pizza to slice it!")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let info = sliceInfo {
                        Text(info)
                            .font(.headline)
                            .foregroundColor(.orange)
                    }

                    // Denominator selector
                    HStack(spacing: 12) {
                        ForEach([2, 3, 4], id: \.self) { d in
                            Button("1/\(d)") {
                                targetDenominator = d
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(targetDenominator == d ? Color.orange : Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding()
            }
        }
        .navigationTitle("AR Fractions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - iOS AR Container

#if os(iOS)
struct FractionARContainer: UIViewRepresentable {
    let targetDenominator: Int
    var onReady: () -> Void
    var onStatusUpdate: (String) -> Void
    var onSliceUpdate: (String) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = context.coordinator.createARView(enablePan: true)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if context.coordinator.targetDenominator != targetDenominator {
            context.coordinator.targetDenominator = targetDenominator
            context.coordinator.resetDisc()
        }
    }

    func makeCoordinator() -> FractionCoordinator {
        FractionCoordinator(
            targetDenominator: targetDenominator,
            onReady: onReady,
            onStatusUpdate: onStatusUpdate,
            onSliceUpdate: onSliceUpdate
        )
    }
}

// MARK: - Fraction Coordinator

class FractionCoordinator: ARSceneCoordinator {
    var targetDenominator: Int
    var onSliceUpdate: (String) -> Void

    // Scene entities
    private var discAnchor: AnchorEntity?
    private var wholeDisc: ModelEntity?
    private var sliceEntities: [ModelEntity] = []
    private var labelEntities: [ModelEntity] = []
    private var isSliced = false
    private var currentSliceCount = 0
    private var selectedSlices: Set<Int> = []

    // Disc dimensions
    private let discRadius: Float = 0.1
    private let discHeight: Float = 0.015

    // Slice colors
    private let sliceColors: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemBlue, .systemPurple, .systemPink, .systemTeal
    ]

    init(targetDenominator: Int,
         onReady: @escaping () -> Void,
         onStatusUpdate: @escaping (String) -> Void,
         onSliceUpdate: @escaping (String) -> Void) {
        self.targetDenominator = targetDenominator
        self.onSliceUpdate = onSliceUpdate
        super.init(onReady: onReady, onStatusUpdate: onStatusUpdate)
    }

    // MARK: - Scene Construction

    override func placeContent(on planeAnchor: ARPlaneAnchor, in session: ARSession) {
        placeDisc()
        speak("Slice the pizza into \(targetDenominator) equal pieces!")
    }

    private func placeDisc() {
        guard let arView = arView else { return }

        // Remove old content
        discAnchor?.removeFromParent()

        let anchor = AnchorEntity(plane: .horizontal)
        anchor.name = "fractionDisc"

        // Create whole disc (cylinder approximated as flat box)
        let mesh = MeshResource.generateBox(
            size: SIMD3<Float>(discRadius * 2, discHeight, discRadius * 2),
            cornerRadius: discRadius * 0.9
        )
        let material = SimpleMaterial(color: .systemOrange, isMetallic: false)
        let disc = ModelEntity(mesh: mesh, materials: [material])
        disc.name = "wholeDisc"
        disc.position = SIMD3<Float>(0, discHeight / 2, 0)
        disc.generateCollisionShapes(recursive: false)

        anchor.addChild(disc)
        arView.scene.addAnchor(anchor)

        self.discAnchor = anchor
        self.wholeDisc = disc
        self.isSliced = false
        self.currentSliceCount = 0
        self.sliceEntities.removeAll()
        self.labelEntities.removeAll()
        self.selectedSlices.removeAll()
    }

    func resetDisc() {
        placeDisc()
        speak("Slice the pizza into \(targetDenominator) equal pieces!")
    }

    // MARK: - Slicing

    private func performSlice() {
        guard !isSliced, let anchor = discAnchor else { return }

        isSliced = true
        currentSliceCount = targetDenominator

        // Hide whole disc
        wholeDisc?.removeFromParent()

        // Create individual slice entities
        let anglePerSlice = (2 * Float.pi) / Float(targetDenominator)

        for i in 0..<targetDenominator {
            let sliceWidth = discRadius * 0.8
            let sliceDepth = discRadius * sin(anglePerSlice / 2) * 1.5
            let mesh = MeshResource.generateBox(
                size: SIMD3<Float>(
                    min(sliceWidth, discRadius),
                    discHeight,
                    max(sliceDepth, 0.02)
                ),
                cornerRadius: 0.003
            )
            let color = sliceColors[i % sliceColors.count]
            let material = SimpleMaterial(color: color, isMetallic: false)
            let slice = ModelEntity(mesh: mesh, materials: [material])
            slice.name = "slice_\(i)"
            slice.generateCollisionShapes(recursive: false)

            slice.position = SIMD3<Float>(0, discHeight / 2, 0)

            anchor.addChild(slice)
            sliceEntities.append(slice)

            // Create fraction label above each slice
            let labelMesh = MeshResource.generateBox(
                size: SIMD3<Float>(0.03, 0.008, 0.015),
                cornerRadius: 0.002
            )
            let labelMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let label = ModelEntity(mesh: labelMesh, materials: [labelMaterial])
            label.name = "label_\(i)_1_\(targetDenominator)"
            label.position = SIMD3<Float>(0, 0.06, 0)

            anchor.addChild(label)
            labelEntities.append(label)
        }

        animateSlicesSeparate()

        speak("You sliced it into \(targetDenominator) pieces! Each piece is one \(denominatorWord(targetDenominator)).")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onSliceUpdate("1/\(self.targetDenominator) each slice")
        }
    }

    private func animateSlicesSeparate() {
        let anglePerSlice = (2 * Float.pi) / Float(targetDenominator)
        let separationRadius: Float = discRadius * 0.6

        for (i, slice) in sliceEntities.enumerated() {
            let angle = Float(i) * anglePerSlice + anglePerSlice / 2
            let targetX = cos(angle) * separationRadius
            let targetZ = sin(angle) * separationRadius

            var transform = slice.transform
            transform.translation = SIMD3<Float>(targetX, discHeight / 2, targetZ)
            transform.rotation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            slice.move(to: transform, relativeTo: slice.parent, duration: 0.5)

            if i < labelEntities.count {
                let label = labelEntities[i]
                var labelTransform = label.transform
                labelTransform.translation = SIMD3<Float>(targetX, 0.07, targetZ)
                label.move(to: labelTransform, relativeTo: label.parent, duration: 0.5)
            }
        }
    }

    private func animateSlicesRecombine() {
        for (i, slice) in sliceEntities.enumerated() {
            var transform = slice.transform
            transform.translation = SIMD3<Float>(0, discHeight / 2, 0)
            transform.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            slice.move(to: transform, relativeTo: slice.parent, duration: 0.5)

            if i < labelEntities.count {
                let label = labelEntities[i]
                var labelTransform = label.transform
                labelTransform.translation = SIMD3<Float>(0, 0.06, 0)
                label.move(to: labelTransform, relativeTo: label.parent, duration: 0.5)
            }
        }

        speak("The pieces come back together to make one whole!")

        DispatchQueue.main.async { [weak self] in
            self?.onSliceUpdate("\(self?.targetDenominator ?? 0)/\(self?.targetDenominator ?? 0) = 1 whole")
        }
    }

    private func denominatorWord(_ d: Int) -> String {
        switch d {
        case 2: return "half"
        case 3: return "third"
        case 4: return "quarter"
        default: return "\(d)th"
        }
    }

    // MARK: - Gesture Handlers

    override func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard let arView = arView else { return }

        let velocity = recognizer.velocity(in: arView)
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)

        // Require a reasonably fast swipe to trigger slice
        if speed > 500 && !isSliced {
            performSlice()
        }
    }

    override func handleEntityTap(_ entity: Entity, in arView: ARView) {
        if entity.name == "wholeDisc" && !isSliced {
            // Tapping whole disc: hint to swipe
            speak("Swipe across the pizza to slice it!")
        } else if entity.name.hasPrefix("slice_"), isSliced {
            // Toggle slice selection
            let indexStr = entity.name.replacingOccurrences(of: "slice_", with: "")
            if let index = Int(indexStr) {
                if selectedSlices.contains(index) {
                    selectedSlices.remove(index)
                    var transform = entity.transform
                    transform.scale = SIMD3(repeating: 1.0)
                    entity.move(to: transform, relativeTo: entity.parent, duration: 0.15)
                } else {
                    selectedSlices.insert(index)
                    var transform = entity.transform
                    transform.scale = SIMD3(repeating: 1.2)
                    transform.translation.y += 0.02
                    entity.move(to: transform, relativeTo: entity.parent, duration: 0.15)
                }

                let numerator = selectedSlices.count
                speak("\(numerator) out of \(targetDenominator)")

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.onSliceUpdate("\(numerator)/\(self.targetDenominator)")
                }

                // If all slices selected, recombine
                if selectedSlices.count == targetDenominator {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.animateSlicesRecombine()
                        self?.selectedSlices.removeAll()
                    }
                }
            }
        }
    }
}
#endif
