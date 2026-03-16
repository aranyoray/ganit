import SwiftUI

// MARK: - Navigation Destination

enum AppDestination: Hashable {
    case home
    case quiz(QuizMode)
    case arQuiz
    case arAddition
    case arFractions
    case arPlaceValue
    case arPlayground
    case arWalkAround
    case arGrouping
    case arCollaborative
    case cognitiveExercises
    case shop
    case profile
    case parentDashboard
    case learningStory
    case parentalConsent
    case settings
}

// MARK: - Home Screen

struct HomeScreen: View {
    @ObservedObject var progressState: ProgressState
    @ObservedObject var questionService: AIQuestionService
    @ObservedObject var signalAggregator: SignalAggregator
    let touchProvider: TouchPatternProvider
    let userGroup: UserGroup
    let firebaseAuth: FirebaseAuthService
    @State private var showDebugOverlay = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    ConsentStatusBanner(user: firebaseAuth.currentUser)
                        .padding(.horizontal)

                    // Score header
                    HStack {
                        Label("\(progressState.score)", systemImage: "star.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        Label("\(progressState.coins)", systemImage: "bitcoinsign.circle.fill")
                            .foregroundColor(.yellow)
                    }
                    .font(.headline)
                    .padding(.horizontal)

                    // XP bar
                    VStack(spacing: 4) {
                        ProgressView(value: progressState.xpRequirements > 0
                            ? Double(progressState.progress) / Double(progressState.xpRequirements) : 0)
                            .padding(.horizontal)
                        Text("\(Int(progressState.progress)) / \(progressState.xpRequirements) XP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Content by user group
                    if userGroup == .child {
                        Text("Choose your mode:")
                            .font(.headline)

                        VStack(spacing: 8) {
                            ForEach(QuizMode.allCases, id: \.self) { mode in
                                NavigationLink(value: AppDestination.quiz(mode)) {
                                    HStack {
                                        Text(mode.symbol).font(.title2)
                                        Text(mode.displayName)
                                        Spacer()
                                        Text("Lv \(progressState.levelFor(mode: mode))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal)

                        NavigationLink(value: AppDestination.arQuiz) {
                            Text("Try AR Mode")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)

                    } else {
                        Text("Cognitive Exercises")
                            .font(.headline)

                        NavigationLink(value: AppDestination.cognitiveExercises) {
                            Text("Brain Training")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)

                        Text("Math Practice")
                            .font(.headline)

                        VStack(spacing: 8) {
                            ForEach(QuizMode.allCases, id: \.self) { mode in
                                NavigationLink(value: AppDestination.quiz(mode)) {
                                    HStack {
                                        Text(mode.symbol).font(.title2)
                                        Text(mode.displayName)
                                        Spacer()
                                        Text("Lv \(progressState.levelFor(mode: mode))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider().padding(.horizontal)

                    // Bottom nav
                    HStack {
                        NavigationLink(value: AppDestination.profile) {
                            VStack {
                                Image(systemName: "person.circle")
                                Text("Profile").font(.caption)
                            }
                        }
                        Spacer()
                        NavigationLink(value: AppDestination.shop) {
                            VStack {
                                Image(systemName: "cart")
                                Text("Shop").font(.caption)
                            }
                        }
                        Spacer()
                        NavigationLink(value: AppDestination.parentDashboard) {
                            VStack {
                                Image(systemName: "chart.bar")
                                Text("Dashboard").font(.caption)
                            }
                        }
                        Spacer()
                        NavigationLink(value: AppDestination.settings) {
                            VStack {
                                Image(systemName: "gearshape")
                                Text("Settings").font(.caption)
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .foregroundColor(.primary)
                }
                .padding(.vertical)
            }
            .navigationTitle("Ganit")
            .navigationDestination(for: AppDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    // MARK: - Destination Router

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .home:
            EmptyView()

        case .quiz(let mode):
            QuizView(viewModel: QuizViewModel(
                mode: mode,
                questionService: questionService,
                progressState: progressState,
                touchProvider: touchProvider
            ))

        case .arQuiz:
            ARQuizView(question: questionService.currentQuestion)

        case .arAddition:
            #if os(iOS)
            AdditionScene()
            #else
            Text("AR requires iOS")
            #endif

        case .arFractions:
            #if os(iOS)
            FractionScene()
            #else
            Text("AR requires iOS")
            #endif

        case .arPlaceValue:
            #if os(iOS)
            PlaceValueScene()
            #else
            Text("AR requires iOS")
            #endif

        case .arPlayground:
            #if os(iOS)
            NumberPlaygroundScene()
            #else
            Text("AR requires iOS")
            #endif

        case .arWalkAround:
            #if os(iOS)
            WalkAroundScene()
            #else
            Text("AR requires iOS")
            #endif

        case .arGrouping:
            #if os(iOS)
            GroupingScene()
            #else
            Text("AR requires iOS")
            #endif

        case .arCollaborative:
            #if os(iOS)
            CollaborativeARView()
            #else
            Text("AR requires iOS")
            #endif

        case .cognitiveExercises:
            CognitiveExerciseView(exerciseType: .memorySequence, config: ContentSelector.CognitiveExerciseConfig(exerciseType: .memorySequence, sequenceLength: 4, optionCount: 4, timeLimit: nil),
                progressState: progressState,
                touchProvider: touchProvider
            )

        case .shop:
            ShopView(progressState: progressState)

        case .profile:
            ProfileView(progressState: progressState)

        case .parentDashboard:
            ParentDashboardView(
                username: progressState.username,
                progressState: progressState,
                screeningResults: EncryptedStorage.shared.loadScreeningResults(user: progressState.username),
                sessionCount: EncryptedStorage.shared.loadSessionIndex(user: progressState.username).count
            )

        case .learningStory:
            LearningStoryView(
                username: progressState.username,
                sessions: loadAllSessions()
            )

        case .parentalConsent:
            ParentalConsentView(
                authService: firebaseAuth,
                username: progressState.username
            )

        case .settings:
            PrivacySettingsView(
                viewModel: PrivacySettingsViewModel(
                    storage: EncryptedStorage.shared,
                    username: progressState.username,
                    parentalConsentGranted: firebaseAuth.currentUser?.consentGranted ?? false
                )
            )
        }
    }

    private func loadAllSessions() -> [SessionRecord] {
        let ids = EncryptedStorage.shared.loadSessionIndex(user: progressState.username)
        return ids.compactMap { EncryptedStorage.shared.loadSession($0, user: progressState.username) }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @ObservedObject var progressState: ProgressState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progressState.xpRequirements > 0
                ? Double(progressState.progress) / Double(progressState.xpRequirements) : 0)
                .padding(.horizontal)

            Text("\(Int(progressState.progress)) out of \(progressState.xpRequirements) XP")

            HStack(spacing: 24) {
                VStack {
                    Text("\(progressState.score)")
                        .font(.title2.bold())
                    Text("Points").font(.caption)
                }
                VStack {
                    Text("\(progressState.coins)")
                        .font(.title2.bold())
                    Text("Coins").font(.caption)
                }
            }

            HStack(spacing: 16) {
                levelItem("+", progressState.additionLevel)
                levelItem("-", progressState.subtractionLevel)
                levelItem("/", progressState.divisionLevel)
                levelItem("*", progressState.multiplicationLevel)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Profile")
    }

    private func levelItem(_ symbol: String, _ level: Int) -> some View {
        VStack {
            Text(symbol).font(.title2)
            Text("Lv \(level)").font(.caption)
        }
    }
}
