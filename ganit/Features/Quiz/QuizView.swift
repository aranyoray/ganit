import SwiftUI

// MARK: - Unified Quiz View

struct QuizView: View {
    @ObservedObject var viewModel: QuizViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            switch viewModel.state {
            case .idle:
                Spacer()
                Text("Loading...")
                    .foregroundColor(.secondary)
                    .task { await viewModel.loadQuestion() }
                Spacer()

            case .loading:
                Spacer()
                ProgressView("Generating question...")
                Spacer()

            case .presenting(let question):
                questionContent(question, answered: false)

            case .answered(_, let question):
                questionContent(question, answered: true)

            case .sessionComplete:
                sessionCompleteView

            case .error(let message):
                Spacer()
                Text(message)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await viewModel.loadQuestion() }
                }
                .buttonStyle(.borderedProminent)
                Button("Use Offline Mode") {
                    viewModel.switchToOffline()
                }
                Spacer()
            }
        }
        .padding()
        .navigationTitle(viewModel.mode.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Progress Bar

    @ViewBuilder
    private var progressHeader: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Q \(viewModel.questionsAnswered + 1)/\(QuizViewModel.questionsPerSession)")
                    .font(.caption.bold())
                Spacer()
                Text("\(viewModel.correctCount) correct")
                    .font(.caption)
                    .foregroundColor(.green)
                Text("Streak: \(viewModel.streak)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(
                            width: geo.size.width * CGFloat(viewModel.questionsAnswered) / CGFloat(QuizViewModel.questionsPerSession),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Question Content

    @ViewBuilder
    private func questionContent(_ question: MCQQuestion, answered: Bool) -> some View {
        progressHeader

        Text("\(viewModel.mode.displayName) — Level \(viewModel.currentLevel)")
            .font(.headline)

        Divider()

        Text(question.question)
            .font(.title2)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        ForEach(0..<question.options.count, id: \.self) { index in
            Button {
                viewModel.selectAnswer(index: index)
            } label: {
                HStack {
                    Text(question.options[index])
                        .foregroundColor(.primary)
                    Spacer()
                    if answered {
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
                .background(optionBackground(index: index, question: question, answered: answered))
                .cornerRadius(10)
            }
            .disabled(answered)
        }

        if !viewModel.resultMessage.isEmpty {
            Text(viewModel.resultMessage)
                .font(.headline)
                .foregroundColor(viewModel.selectedIndex == question.correct_index ? .green : .red)
        }

        if viewModel.showHint {
            Text("Hint: \(question.hint)")
                .font(.callout)
                .foregroundColor(.orange)
        }

        if answered {
            Button("Next Question") {
                viewModel.nextQuestion()
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button("Show Hint") {
                viewModel.showHint = true
            }
            .foregroundColor(.orange)
        }

        Spacer()
    }

    // MARK: - Session Complete

    @ViewBuilder
    private var sessionCompleteView: some View {
        Spacer()

        let accuracy = viewModel.questionsAnswered > 0
            ? Double(viewModel.correctCount) / Double(viewModel.questionsAnswered)
            : 0

        VStack(spacing: 12) {
            Image(systemName: accuracy >= 0.7 ? "star.fill" : "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(accuracy >= 0.7 ? .yellow : .blue)

            Text(accuracy >= 0.9 ? "Excellent!" : accuracy >= 0.7 ? "Great job!" : accuracy >= 0.5 ? "Good effort!" : "Keep practicing!")
                .font(.title.bold())

            Text("\(viewModel.mode.displayName) Session Complete")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }

        Divider().padding(.horizontal)

        // Stats grid
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                statBox(value: "\(viewModel.correctCount)/\(viewModel.questionsAnswered)", label: "Correct", color: .green)
                statBox(value: "\(Int(accuracy * 100))%", label: "Accuracy", color: .blue)
            }
            HStack(spacing: 24) {
                statBox(value: "\(viewModel.bestStreak)", label: "Best Streak", color: .orange)
                statBox(value: "\(Int(viewModel.sessionXPEarned))", label: "XP Earned", color: .purple)
            }
        }

        Divider().padding(.horizontal)

        // Coin reward
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundColor(.yellow)
                .font(.title2)
            Text("+\(viewModel.sessionCoinsEarned) coins")
                .font(.title3.bold())
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)

        Spacer()

        // Actions
        VStack(spacing: 10) {
            Button("Play Again") {
                viewModel.startNewSession()
            }
            .buttonStyle(.borderedProminent)

            Button("Done") {
                dismiss()
            }
            .foregroundColor(.secondary)
        }

        Spacer()
    }

    // MARK: - Helpers

    private func statBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }

    private func optionBackground(index: Int, question: MCQQuestion, answered: Bool) -> Color {
        guard answered else { return Color.gray.opacity(0.1) }
        if index == question.correct_index { return Color.green.opacity(0.2) }
        if index == viewModel.selectedIndex { return Color.red.opacity(0.2) }
        return Color.gray.opacity(0.05)
    }
}
