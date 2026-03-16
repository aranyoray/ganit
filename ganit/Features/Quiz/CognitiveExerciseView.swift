import SwiftUI
import Combine

// MARK: - Cognitive Exercise View

/// Main container that routes to the appropriate exercise view for elderly users.
/// Tracks response latency and hesitation via TouchPatternProvider hooks.
struct CognitiveExerciseView: View {
    let exerciseType: ContentSelector.CognitiveExerciseType
    let config: ContentSelector.CognitiveExerciseConfig
    @ObservedObject var progressState: ProgressState
    @ObservedObject var touchProvider: TouchPatternProvider

    var body: some View {
        Group {
            switch exerciseType {
            case .memorySequence:
                MemorySequenceView(
                    config: config,
                    progressState: progressState,
                    touchProvider: touchProvider
                )
            case .patternRecognition:
                PatternRecognitionView(
                    config: config,
                    progressState: progressState,
                    touchProvider: touchProvider
                )
            case .wordPuzzle:
                WordPuzzleView(
                    config: config,
                    progressState: progressState,
                    touchProvider: touchProvider
                )
            }
        }
        .padding()
    }
}

// MARK: - Memory Sequence View

/// Show a sequence of numbers/colors, then ask the user to recall them.
/// Starts with 3 items; sequence length is driven by config.
struct MemorySequenceView: View {
    let config: ContentSelector.CognitiveExerciseConfig
    @ObservedObject var progressState: ProgressState
    @ObservedObject var touchProvider: TouchPatternProvider

    @State private var sequence: [Int] = []
    @State private var userInput: [Int] = []
    @State private var phase: MemoryPhase = .showing
    @State private var currentShowIndex: Int = 0
    @State private var resultMessage: String = ""
    @State private var isCorrect: Bool?
    @State private var exerciseStartTime: Date = Date()

    private enum MemoryPhase {
        case showing
        case recalling
        case result
    }

    private let sequenceColors: [Color] = [
        .blue, .teal, .orange, .purple, .pink, .indigo, .mint, .cyan, .brown
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("Memory Sequence")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            Text(phaseInstruction)
                .font(.system(size: 20))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            switch phase {
            case .showing:
                showingPhaseContent

            case .recalling:
                recallingPhaseContent

            case .result:
                resultPhaseContent
            }

            Spacer()
        }
        .onAppear {
            generateSequence()
            startShowingPhase()
        }
    }

    // MARK: - Phase Content

    @ViewBuilder
    private var showingPhaseContent: some View {
        if currentShowIndex < sequence.count {
            let number = sequence[currentShowIndex]
            RoundedRectangle(cornerRadius: 20)
                .fill(sequenceColors[number % sequenceColors.count].opacity(0.3))
                .frame(width: 140, height: 140)
                .overlay(
                    Text("\(number)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                )
                .accessibilityLabel("Number \(number)")
        } else {
            ProgressView()
                .scaleEffect(1.5)
        }
    }

    @ViewBuilder
    private var recallingPhaseContent: some View {
        // Show what user has entered so far
        HStack(spacing: 12) {
            ForEach(0..<config.sequenceLength, id: \.self) { index in
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Group {
                            if index < userInput.count {
                                Text("\(userInput[index])")
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                            }
                        }
                    )
            }
        }
        .padding(.bottom, 16)

        // Number pad
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(1...9, id: \.self) { number in
                Button {
                    numberTapped(number)
                } label: {
                    Text("\(number)")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .frame(width: 64, height: 64)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                .disabled(userInput.count >= config.sequenceLength)
            }
        }
        .padding(.horizontal, 40)

        HStack(spacing: 20) {
            Button("Clear") {
                userInput.removeAll()
            }
            .font(.system(size: 18))
            .foregroundColor(.orange)
            .disabled(userInput.isEmpty)

            Button("Undo") {
                if !userInput.isEmpty {
                    userInput.removeLast()
                    touchProvider.optionDeselected(index: userInput.count)
                }
            }
            .font(.system(size: 18))
            .foregroundColor(.secondary)
            .disabled(userInput.isEmpty)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var resultPhaseContent: some View {
        VStack(spacing: 16) {
            Image(systemName: isCorrect == true ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(isCorrect == true ? .teal : .orange)

            Text(resultMessage)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            if isCorrect != true {
                Text("The sequence was: \(sequence.map(String.init).joined(separator: ", "))")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }

            Button("Next Exercise") {
                resetExercise()
            }
            .font(.system(size: 20, weight: .semibold))
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color.teal.opacity(0.2))
            .foregroundColor(.teal)
            .cornerRadius(12)
            .padding(.top, 8)
        }
    }

    // MARK: - Phase Instruction

    private var phaseInstruction: String {
        switch phase {
        case .showing:
            return "Watch the numbers carefully..."
        case .recalling:
            return "Enter the numbers in order"
        case .result:
            return ""
        }
    }

    // MARK: - Logic

    private func generateSequence() {
        sequence = (0..<config.sequenceLength).map { _ in Int.random(in: 1...9) }
    }

    private func startShowingPhase() {
        currentShowIndex = 0
        phase = .showing
        exerciseStartTime = Date()
        showNextItem()
    }

    private func showNextItem() {
        guard currentShowIndex < sequence.count else {
            // Transition to recall phase
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                phase = .recalling
                touchProvider.questionDidAppear()
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            currentShowIndex += 1
            showNextItem()
        }
    }

    private func numberTapped(_ number: Int) {
        guard userInput.count < config.sequenceLength else { return }

        touchProvider.optionSelected(index: number)
        userInput.append(number)

        if userInput.count == config.sequenceLength {
            checkAnswer()
        }
    }

    private func checkAnswer() {
        touchProvider.answerSubmitted()
        let correct = userInput == sequence
        isCorrect = correct

        if correct {
            resultMessage = "Excellent! You remembered the whole sequence!"
            progressState.score += 10
            HapticManager.success()
        } else {
            resultMessage = "Good try! Keep practicing."
            HapticManager.light()
        }

        phase = .result
    }

    private func resetExercise() {
        userInput.removeAll()
        resultMessage = ""
        isCorrect = nil
        generateSequence()
        startShowingPhase()
    }
}

// MARK: - Pattern Recognition View

/// Show a pattern (e.g., 2, 4, 6, ?) and ask for the next number. Multiple choice.
struct PatternRecognitionView: View {
    let config: ContentSelector.CognitiveExerciseConfig
    @ObservedObject var progressState: ProgressState
    @ObservedObject var touchProvider: TouchPatternProvider

    @State private var patternNumbers: [Int] = []
    @State private var correctAnswer: Int = 0
    @State private var options: [Int] = []
    @State private var selectedIndex: Int?
    @State private var answered: Bool = false
    @State private var resultMessage: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Pattern Recognition")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            Text("What comes next in the pattern?")
                .font(.system(size: 20))
                .foregroundColor(.secondary)

            Spacer()

            // Pattern display
            HStack(spacing: 16) {
                ForEach(patternNumbers.indices, id: \.self) { index in
                    Text("\(patternNumbers[index])")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .frame(width: 56, height: 56)
                        .background(Color.teal.opacity(0.15))
                        .cornerRadius(12)
                }

                Text("?")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .frame(width: 56, height: 56)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(12)
            }
            .padding(.vertical, 16)

            // Options
            VStack(spacing: 12) {
                ForEach(0..<options.count, id: \.self) { index in
                    Button {
                        selectOption(index)
                    } label: {
                        HStack {
                            Text("\(options[index])")
                                .font(.system(size: 24, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                            if answered {
                                if options[index] == correctAnswer {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.teal)
                                } else if index == selectedIndex {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding()
                        .background(optionBackground(index))
                        .cornerRadius(12)
                    }
                    .disabled(answered)
                }
            }
            .padding(.horizontal)

            if !resultMessage.isEmpty {
                Text(resultMessage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(selectedIndex.map({ options[$0] == correctAnswer }) == true ? .teal : .orange)
                    .padding(.top, 4)
            }

            if answered {
                Button("Next Pattern") {
                    resetExercise()
                }
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.teal.opacity(0.2))
                .foregroundColor(.teal)
                .cornerRadius(12)
            }

            Spacer()
        }
        .onAppear {
            generatePattern()
            touchProvider.questionDidAppear()
        }
    }

    // MARK: - Logic

    private func generatePattern() {
        let patternType = Int.random(in: 0...2)
        let start = Int.random(in: 1...10)
        let step: Int

        switch patternType {
        case 0: // Arithmetic: +step
            step = Int.random(in: 2...5)
            patternNumbers = (0..<config.sequenceLength).map { start + $0 * step }
            correctAnswer = start + config.sequenceLength * step

        case 1: // Arithmetic: *2
            patternNumbers = (0..<config.sequenceLength).map { start * Int(pow(2.0, Double($0))) }
            correctAnswer = start * Int(pow(2.0, Double(config.sequenceLength)))

        default: // Arithmetic: +increasing step (1, 3, 6, 10, ...)
            var nums = [start]
            for i in 1..<config.sequenceLength {
                nums.append(nums[i - 1] + (i + 1))
            }
            patternNumbers = nums
            correctAnswer = nums.last! + (config.sequenceLength + 1)
        }

        // Generate options including the correct answer
        var optionSet: Set<Int> = [correctAnswer]
        while optionSet.count < config.optionCount {
            let offset = Int.random(in: 1...5) * (Bool.random() ? 1 : -1)
            let wrong = correctAnswer + offset
            if wrong > 0 { optionSet.insert(wrong) }
        }
        options = Array(optionSet).shuffled()
    }

    private func selectOption(_ index: Int) {
        guard !answered else { return }

        if let prev = selectedIndex, prev != index {
            touchProvider.optionDeselected(index: prev)
        }

        selectedIndex = index
        answered = true
        touchProvider.optionSelected(index: index)
        touchProvider.answerSubmitted()

        let correct = options[index] == correctAnswer
        if correct {
            resultMessage = "Correct! Great pattern recognition!"
            progressState.score += 10
            HapticManager.success()
        } else {
            resultMessage = "The answer is \(correctAnswer). Keep going!"
            HapticManager.light()
        }
    }

    private func optionBackground(_ index: Int) -> Color {
        guard answered else { return Color.secondary.opacity(0.08) }
        if options[index] == correctAnswer { return Color.teal.opacity(0.15) }
        if index == selectedIndex { return Color.orange.opacity(0.15) }
        return Color.secondary.opacity(0.04)
    }

    private func resetExercise() {
        selectedIndex = nil
        answered = false
        resultMessage = ""
        generatePattern()
        touchProvider.questionDidAppear()
    }
}

// MARK: - Word Puzzle View

/// Unscramble a word or find the odd-word-out from a list.
struct WordPuzzleView: View {
    let config: ContentSelector.CognitiveExerciseConfig
    @ObservedObject var progressState: ProgressState
    @ObservedObject var touchProvider: TouchPatternProvider

    @State private var puzzleType: WordPuzzleType = .oddOneOut
    @State private var words: [String] = []
    @State private var correctIndex: Int = 0
    @State private var scrambledWord: String = ""
    @State private var originalWord: String = ""
    @State private var userGuess: String = ""
    @State private var selectedIndex: Int?
    @State private var answered: Bool = false
    @State private var resultMessage: String = ""

    private enum WordPuzzleType {
        case oddOneOut
        case unscramble
    }

    // Word banks for exercises
    private static let categoryWords: [(category: String, words: [String], oddWord: String)] = [
        ("Fruits", ["Apple", "Banana", "Orange", "Mango"], "Chair"),
        ("Animals", ["Dog", "Cat", "Horse", "Bird"], "Table"),
        ("Colors", ["Red", "Blue", "Green", "Yellow"], "Pizza"),
        ("Vehicles", ["Car", "Bus", "Train", "Bicycle"], "Flower"),
        ("Furniture", ["Desk", "Chair", "Sofa", "Bed"], "Tiger"),
        ("Months", ["March", "June", "April", "August"], "Hammer"),
        ("Instruments", ["Piano", "Guitar", "Drum", "Violin"], "Bread"),
        ("Clothing", ["Shirt", "Pants", "Jacket", "Shoes"], "River"),
    ]

    private static let unscrambleWords: [String] = [
        "APPLE", "HOUSE", "WATER", "CHAIR", "TABLE",
        "MUSIC", "PLANT", "LIGHT", "BREAD", "CLOUD",
        "SMILE", "HEART", "BOOKS", "RIVER", "STONE"
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("Word Puzzle")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            Text(puzzleInstruction)
                .font(.system(size: 20))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            switch puzzleType {
            case .oddOneOut:
                oddOneOutContent

            case .unscramble:
                unscrambleContent
            }

            if !resultMessage.isEmpty {
                Text(resultMessage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isAnswerCorrect ? .teal : .orange)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            if answered {
                Button("Next Puzzle") {
                    resetExercise()
                }
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.teal.opacity(0.2))
                .foregroundColor(.teal)
                .cornerRadius(12)
            }

            Spacer()
        }
        .onAppear {
            generatePuzzle()
            touchProvider.questionDidAppear()
        }
    }

    // MARK: - Odd One Out Content

    @ViewBuilder
    private var oddOneOutContent: some View {
        VStack(spacing: 12) {
            ForEach(0..<words.count, id: \.self) { index in
                Button {
                    selectOddOneOut(index)
                } label: {
                    HStack {
                        Text(words[index])
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                        if answered {
                            if index == correctIndex {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.teal)
                            } else if index == selectedIndex {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding()
                    .background(oddOneOutBackground(index))
                    .cornerRadius(12)
                }
                .disabled(answered)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Unscramble Content

    @ViewBuilder
    private var unscrambleContent: some View {
        VStack(spacing: 20) {
            // Scrambled word display
            HStack(spacing: 8) {
                ForEach(Array(scrambledWord.enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .frame(width: 48, height: 48)
                        .background(Color.indigo.opacity(0.12))
                        .cornerRadius(10)
                }
            }

            TextField("Type your answer", text: $userGuess)
                .font(.system(size: 22))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .padding(.horizontal, 40)
                .disabled(answered)

            if !answered {
                Button("Submit") {
                    submitUnscramble()
                }
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.teal.opacity(0.2))
                .foregroundColor(.teal)
                .cornerRadius(12)
                .disabled(userGuess.isEmpty)
            }
        }
    }

    // MARK: - Helpers

    private var puzzleInstruction: String {
        switch puzzleType {
        case .oddOneOut:
            return "Which word does not belong?"
        case .unscramble:
            return "Unscramble the letters to form a word"
        }
    }

    private var isAnswerCorrect: Bool {
        switch puzzleType {
        case .oddOneOut:
            return selectedIndex == correctIndex
        case .unscramble:
            return userGuess.uppercased().trimmingCharacters(in: .whitespaces) == originalWord
        }
    }

    private func oddOneOutBackground(_ index: Int) -> Color {
        guard answered else { return Color.secondary.opacity(0.08) }
        if index == correctIndex { return Color.teal.opacity(0.15) }
        if index == selectedIndex { return Color.orange.opacity(0.15) }
        return Color.secondary.opacity(0.04)
    }

    // MARK: - Logic

    private func generatePuzzle() {
        puzzleType = Bool.random() ? .oddOneOut : .unscramble

        switch puzzleType {
        case .oddOneOut:
            guard let category = Self.categoryWords.randomElement() else { return }
            var allWords = category.words.prefix(config.optionCount - 1).map { $0 }
            allWords.append(category.oddWord)
            correctIndex = allWords.count - 1
            words = allWords.shuffled()
            // Find the new index of the odd word after shuffling
            correctIndex = words.firstIndex(of: category.oddWord) ?? 0

        case .unscramble:
            guard let word = Self.unscrambleWords.randomElement() else { return }
            originalWord = word
            scrambledWord = String(word.shuffled())
            // Ensure it is actually scrambled
            while scrambledWord == word && word.count > 1 {
                scrambledWord = String(word.shuffled())
            }
        }
    }

    private func selectOddOneOut(_ index: Int) {
        guard !answered else { return }

        if let prev = selectedIndex, prev != index {
            touchProvider.optionDeselected(index: prev)
        }

        selectedIndex = index
        answered = true
        touchProvider.optionSelected(index: index)
        touchProvider.answerSubmitted()

        if index == correctIndex {
            resultMessage = "Correct! \"\(words[index])\" is the odd one out."
            progressState.score += 10
            HapticManager.success()
        } else {
            resultMessage = "The odd one out was \"\(words[correctIndex])\"."
            HapticManager.light()
        }
    }

    private func submitUnscramble() {
        guard !answered else { return }
        answered = true
        touchProvider.answerSubmitted()

        if userGuess.uppercased().trimmingCharacters(in: .whitespaces) == originalWord {
            resultMessage = "Correct! The word is \(originalWord)."
            progressState.score += 10
            HapticManager.success()
        } else {
            resultMessage = "The word was \(originalWord). Nice try!"
            HapticManager.light()
        }
    }

    private func resetExercise() {
        selectedIndex = nil
        answered = false
        resultMessage = ""
        userGuess = ""
        generatePuzzle()
        touchProvider.questionDidAppear()
    }
}
