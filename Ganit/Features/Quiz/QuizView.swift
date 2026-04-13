import SwiftUI

// MARK: - Unified Quiz View

/// Single parameterized quiz view replacing Addition, Subtraction, Multiplication,
/// Division, and AIQuizView. Supports all modes with signal collection hooks.
struct QuizView: View {
    @ObservedObject var viewModel: QuizViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                Spacer()
                ProgressView("Generating question...")
                Spacer()
            } else if let question = viewModel.currentQuestion {
                questionContent(question)
            } else if let error = viewModel.errorMessage {
                errorContent(error)
            } else {
                Spacer()
                Text("Loading...")
                    .foregroundColor(.secondary)
                    .task { await viewModel.loadQuestion() }
                Spacer()
            }
        }
        .padding()
        .navigationTitle(viewModel.mode.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Question Content

    @ViewBuilder
    private func questionContent(_ question: MCQQuestion) -> some View {
        // Header
        HStack {
            VStack(alignment: .leading) {
                Text("\(viewModel.mode.displayName) — Level \(viewModel.currentLevel)")
                    .font(.headline)
                Text("Points: \(viewModel.resultMessage.isEmpty ? "\(0)" : "") | Streak: \(viewModel.streak)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(Int(viewModel.accuracy * 100))% accuracy")
                .font(.caption)
                .padding(6)
                .background(accuracyColor.opacity(0.2))
                .cornerRadius(8)
        }

        Divider()

        // Question text
        Text(question.question)
            .font(.title2)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        // Options
        ForEach(0..<question.options.count, id: \.self) { index in
            Button {
                viewModel.selectAnswer(index: index)
            } label: {
                HStack {
                    Text(question.options[index])
                        .foregroundColor(.primary)
                    Spacer()
                    if viewModel.answered {
                        if index == question.correct_index {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if index == viewModel.selectedIndex {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(optionBackground(index: index, question: question))
                .cornerRadius(10)
            }
            .disabled(viewModel.answered)
        }

        // Result message
        if !viewModel.resultMessage.isEmpty {
            Text(viewModel.resultMessage)
                .font(.headline)
                .foregroundColor(viewModel.selectedIndex == question.correct_index ? .green : .red)
                .padding(.top, 4)
        }

        // Hint
        if viewModel.showHint {
            Text("Hint: \(question.hint)")
                .font(.callout)
                .foregroundColor(.orange)
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
        }

        // Action buttons
        if viewModel.answered {
            Button("Next Question") {
                viewModel.nextQuestion()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        } else {
            Button("Show Hint") {
                viewModel.showHint = true
            }
            .foregroundColor(.orange)
        }

        Spacer()
    }

    // MARK: - Error Content

    @ViewBuilder
    private func errorContent(_ error: String) -> some View {
        Spacer()
        VStack(spacing: 12) {
            Text(error)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await viewModel.loadQuestion() }
            }
            Button("Use Offline Mode") {
                viewModel.switchToOffline()
            }
        }
        .padding()
        Spacer()
    }

    // MARK: - Helpers

    private func optionBackground(index: Int, question: MCQQuestion) -> Color {
        guard viewModel.answered else { return Color.gray.opacity(0.1) }
        if index == question.correct_index { return Color.green.opacity(0.2) }
        if index == viewModel.selectedIndex { return Color.red.opacity(0.2) }
        return Color.gray.opacity(0.05)
    }

    private var accuracyColor: Color {
        if viewModel.accuracy >= 0.75 { return .green }
        if viewModel.accuracy >= 0.5 { return .orange }
        return .red
    }
}
