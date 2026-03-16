import SwiftUI

// MARK: - Parent Dashboard

struct ParentDashboardView: View {
    let username: String
    let progressState: ProgressState
    let screeningResults: [ScreeningResult]
    let sessionCount: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Dashboard for \(username)")
                    .font(.title2.bold())

                // Stats
                HStack {
                    VStack {
                        Text("\(progressState.score)").font(.title.bold())
                        Text("Points").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack {
                        Text("\(progressState.coins)").font(.title.bold())
                        Text("Coins").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack {
                        Text("\(sessionCount)").font(.title.bold())
                        Text("Sessions").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                // Skill Levels
                Text("Skill Levels")
                    .font(.headline)

                HStack(spacing: 16) {
                    levelBadge("+", level: progressState.additionLevel)
                    levelBadge("-", level: progressState.subtractionLevel)
                    levelBadge("/", level: progressState.divisionLevel)
                    levelBadge("*", level: progressState.multiplicationLevel)
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }

    private func levelBadge(_ symbol: String, level: Int) -> some View {
        VStack {
            Text(symbol).font(.title2.bold())
            Text("Lv \(level)").font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
