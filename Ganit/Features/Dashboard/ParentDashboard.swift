import SwiftUI

// MARK: - Parent Dashboard

/// Shows learning progress and early screening indicators.
struct ParentDashboardView: View {
    let username: String
    let progressState: ProgressState
    let screeningResults: [ScreeningResult]
    let sessionCount: Int
    @StateObject private var consentManager: InsightsConsentManager
    @State private var showDeleteConfirmation = false

    init(username: String, progressState: ProgressState, screeningResults: [ScreeningResult], sessionCount: Int) {
        self.username = username
        self.progressState = progressState
        self.screeningResults = screeningResults
        self.sessionCount = sessionCount
        _consentManager = StateObject(wrappedValue: InsightsConsentManager(user: username))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Learning Dashboard")
                    .font(.title2.bold())
                Text("for \(username)")
                    .foregroundColor(.secondary)

                // Progress section
                progressSection

                // Level breakdown
                levelBreakdown

                // Learning insights (gated behind consent)
                if !consentManager.hasConsented {
                    InsightsConsentView {
                        consentManager.grantConsent()
                    }
                } else if sessionCount >= 10 {
                    screeningSection
                    LearningInsightsDisclaimerView(compact: true)
                } else {
                    insufficientDataSection
                }

                // Account management
                Divider()
                accountDeletionSection
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overall Progress")
                .font(.headline)

            HStack {
                VStack {
                    Text("\(progressState.score)")
                        .font(.title.bold())
                    Text("Points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack {
                    Text("\(progressState.coins)")
                        .font(.title.bold())
                    Text("Coins")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack {
                    Text("\(sessionCount)")
                        .font(.title.bold())
                    Text("Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Levels

    @ViewBuilder
    private var levelBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skill Levels")
                .font(.headline)

            HStack(spacing: 16) {
                levelBadge("+", level: progressState.additionLevel, color: .blue)
                levelBadge("-", level: progressState.subtractionLevel, color: .green)
                levelBadge("/", level: progressState.divisionLevel, color: .orange)
                levelBadge("*", level: progressState.multiplicationLevel, color: .purple)
            }
        }
    }

    private func levelBadge(_ symbol: String, level: Int, color: Color) -> some View {
        VStack {
            Text(symbol)
                .font(.title2.bold())
                .foregroundColor(color)
            Text("Lv \(level)")
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Screening

    @ViewBuilder
    private var screeningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Learning Insights")
                .font(.headline)

            let flagged = screeningResults.filter(\.shouldRecommendProfessional)

            if flagged.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No concerning patterns detected. Keep up the great work!")
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            } else {
                ForEach(flagged) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                            Text(result.condition.displayName.capitalized)
                                .font(.subheadline.bold())
                        }

                        Text("We've noticed some patterns that may be worth discussing with a learning specialist. This is not a diagnosis.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(result.indicators, id: \.name) { indicator in
                            HStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                                Text(indicator.description)
                                    .font(.caption2)
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
            }

            Text("Based on \(sessionCount) learning sessions. Minimum 10 required for insights.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var accountDeletionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Account Management")
                .font(.headline)

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Account & Data")
                }
            }
            .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) {
                    AuthService().deleteAccount(username: username)
                }
            } message: {
                Text("This will permanently delete all learning data, progress, screening insights, and account information. This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private var insufficientDataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Learning Insights")
                .font(.headline)

            HStack {
                Image(systemName: "hourglass")
                    .foregroundColor(.secondary)
                VStack(alignment: .leading) {
                    Text("Building your learning profile...")
                    Text("\(sessionCount)/10 sessions completed. Keep practicing!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}
