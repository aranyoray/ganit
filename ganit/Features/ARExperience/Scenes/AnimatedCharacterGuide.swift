import Foundation
import SwiftUI
import RealityKit
import ARKit
import Combine
import AVFoundation

#if os(iOS)

// MARK: - Animated Character Guide

/// A 3D character that reacts to the child's facial expressions in real-time.
/// Celebrates on smile, offers encouragement on confusion, comforts on frustration.
@MainActor
class AnimatedCharacterGuide: ObservableObject {

    @Published var currentMood: CharacterMood = .neutral
    @Published var speechBubbleText: String = ""

    private var characterEntity: ModelEntity?
    private var speechBubbleEntity: ModelEntity?
    private let synthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()

    // Base character properties
    private let characterSize: Float = 0.12
    private let bounceAmplitude: Float = 0.005
    private var idleTimer: Timer?

    enum CharacterMood: String {
        case happy, encouraging, comforting, celebrating, neutral, thinking
    }

    // MARK: - Setup

    /// Creates the character entity and adds it to the scene anchor.
    func createCharacter(at position: SIMD3<Float>) -> ModelEntity {
        // Body: rounded cube (friendly shape)
        let bodyMesh = MeshResource.generateBox(
            size: characterSize,
            cornerRadius: characterSize * 0.3
        )
        let bodyMaterial = SimpleMaterial(
            color: .systemTeal,
            isMetallic: false
        )
        let body = ModelEntity(mesh: bodyMesh, materials: [bodyMaterial])
        body.position = position
        body.name = "character_guide"

        // Eyes: two small white spheres
        let eyeMesh = MeshResource.generateSphere(radius: characterSize * 0.12)
        let eyeMaterial = SimpleMaterial(color: .white, isMetallic: false)

        let leftEye = ModelEntity(mesh: eyeMesh, materials: [eyeMaterial])
        leftEye.position = SIMD3(-characterSize * 0.2, characterSize * 0.15, characterSize * 0.45)
        leftEye.name = "left_eye"

        let rightEye = ModelEntity(mesh: eyeMesh, materials: [eyeMaterial])
        rightEye.position = SIMD3(characterSize * 0.2, characterSize * 0.15, characterSize * 0.45)
        rightEye.name = "right_eye"

        // Pupils: tiny black spheres
        let pupilMesh = MeshResource.generateSphere(radius: characterSize * 0.06)
        let pupilMaterial = SimpleMaterial(color: .black, isMetallic: false)

        let leftPupil = ModelEntity(mesh: pupilMesh, materials: [pupilMaterial])
        leftPupil.position = SIMD3(0, 0, characterSize * 0.06)

        let rightPupil = ModelEntity(mesh: pupilMesh, materials: [pupilMaterial])
        rightPupil.position = SIMD3(0, 0, characterSize * 0.06)

        leftEye.addChild(leftPupil)
        rightEye.addChild(rightPupil)
        body.addChild(leftEye)
        body.addChild(rightEye)

        characterEntity = body
        startIdleAnimation()
        return body
    }

    // MARK: - React to Expressions

    /// Updates character based on detected child expression.
    func reactToExpression(_ expression: ExpressionCategory) {
        switch expression {
        case .engaged:
            setMood(.happy)
        case .confused:
            setMood(.thinking)
            showSpeechBubble("Hmm, let me help you think about this!")
            speak("Let me help you think about this")
        case .frustrated:
            setMood(.comforting)
            showSpeechBubble("It's okay! Math can be tricky. Take your time.")
            speak("It's okay! Take your time.")
        case .anxious:
            setMood(.comforting)
            showSpeechBubble("You're doing great! No rush at all.")
            speak("You're doing great!")
        case .bored:
            setMood(.encouraging)
            showSpeechBubble("Want to try something more exciting?")
            speak("Want to try something more exciting?")
        case .neutral, .ambiguous:
            setMood(.neutral)
        }
    }

    /// Celebrate a correct answer.
    func celebrateCorrectAnswer() {
        setMood(.celebrating)
        showSpeechBubble("Amazing! You got it right!")
        speak("Amazing!")
        playBounceAnimation(intensity: 3.0)

        // Return to neutral after celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.setMood(.neutral)
            self?.speechBubbleText = ""
        }
    }

    /// Encourage after a wrong answer (anxiety-friendly).
    func encourageAfterWrong() {
        setMood(.encouraging)
        showSpeechBubble("Almost! Let's try again together.")
        speak("Almost! Let's try again.")
        playTiltAnimation()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.setMood(.neutral)
            self?.speechBubbleText = ""
        }
    }

    // MARK: - Mood & Animation

    private func setMood(_ mood: CharacterMood) {
        currentMood = mood
        guard let character = characterEntity else { return }

        let color: UIColor
        switch mood {
        case .happy:        color = .systemGreen
        case .encouraging:  color = .systemBlue
        case .comforting:   color = .systemPurple
        case .celebrating:  color = .systemYellow
        case .neutral:      color = .systemTeal
        case .thinking:     color = .systemOrange
        }

        // Animate color change
        let material = SimpleMaterial(color: color, isMetallic: false)
        character.model?.materials = [material]

        // Scale animation for mood change
        var transform = character.transform
        transform.scale = SIMD3(repeating: 1.1)
        character.move(to: transform, relativeTo: character.parent, duration: 0.2)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            var resetTransform = character.transform
            resetTransform.scale = SIMD3(repeating: 1.0)
            character.move(to: resetTransform, relativeTo: character.parent, duration: 0.2)
        }
    }

    private func startIdleAnimation() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playBounceAnimation(intensity: 1.0)
            }
        }
    }


    private func playBounceAnimation(intensity: Float) {
        guard let character = characterEntity else { return }
        let originalY = character.position.y

        var upTransform = character.transform
        upTransform.translation.y = originalY + bounceAmplitude * intensity
        character.move(to: upTransform, relativeTo: character.parent, duration: 0.15)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            var downTransform = character.transform
            downTransform.translation.y = originalY
            character.move(to: downTransform, relativeTo: character.parent, duration: 0.15)
        }
    }

    private func playTiltAnimation() {
        guard let character = characterEntity else { return }

        var tiltTransform = character.transform
        tiltTransform.rotation = simd_quatf(angle: .pi / 12, axis: SIMD3(0, 0, 1))
        character.move(to: tiltTransform, relativeTo: character.parent, duration: 0.2)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            var resetTransform = character.transform
            resetTransform.rotation = simd_quatf(angle: 0, axis: SIMD3(0, 0, 1))
            character.move(to: resetTransform, relativeTo: character.parent, duration: 0.2)
        }
    }

    // MARK: - Speech

    private func showSpeechBubble(_ text: String) {
        speechBubbleText = text
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.2  // Slightly higher pitch for friendly tone
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    // MARK: - Cleanup

    func cleanup() {
        idleTimer?.invalidate()
        idleTimer = nil
        synthesizer.stopSpeaking(at: .immediate)
        characterEntity?.removeFromParent()
        characterEntity = nil
    }

    deinit {
        idleTimer?.invalidate()
    }
}

// MARK: - Character Guide SwiftUI Overlay

/// SwiftUI overlay showing the character's speech bubble.
struct CharacterSpeechBubble: View {
    let text: String
    let mood: AnimatedCharacterGuide.CharacterMood

    var body: some View {
        if !text.isEmpty {
            HStack(spacing: 8) {
                moodEmoji
                    .font(.title2)
                Text(text)
                    .font(.callout)
                    .foregroundColor(.primary)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(radius: 4)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.4), value: text)
        }
    }

    private var moodEmoji: Text {
        switch mood {
        case .happy:        return Text("😊")
        case .encouraging:  return Text("💪")
        case .comforting:   return Text("🤗")
        case .celebrating:  return Text("🎉")
        case .neutral:      return Text("🤖")
        case .thinking:     return Text("🤔")
        }
    }
}

#endif
