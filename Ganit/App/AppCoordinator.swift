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

/// Main hub after authentication. NavigationStack-based routing.
struct HomeScreen: View {
    @ObservedObject var progressState: ProgressState
    @ObservedObject var questionService: AIQuestionService
    @ObservedObject var signalAggregator: SignalAggregator
    let touchProvider: TouchPatternProvider
    let userGroup: UserGroup
    let authService: AuthService
    @State private var showDebugOverlay = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Consent banner for children
                        ConsentStatusBanner(user: authService.currentUser)
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

                        // XP Progress bar
                        xpProgressBar

                        // Content varies by user group
                        if userGroup == .child {
                            childContent
                        } else {
                            elderlyContent
                        }

                        // Common bottom nav
                        bottomNavigation

                        // Debug overlay toggle
                        Toggle("Debug Overlay", isOn: $showDebugOverlay)
                            .font(.caption)
                            .padding(.horizontal, 40)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Ganit")
                .navigationDestination(for: AppDestination.self) { destination in
                    destinationView(for: destination)
                }

                // Debug overlay
                if showDebugOverlay {
                    DebugOverlayView(
                        snapshot: signalAggregator.latestSnapshot,
                        engagementState: signalAggregator.engagementState,
                        difficulty: .medium,
                        sessionCount: EncryptedStorage.shared.loadSessionIndex(user: progressState.username).count,
                        isVisible: true
                    )
                    .padding(.top, 60)
                }
            }
        }
    }

    // MARK: - Child Content

    @ViewBuilder
    private var childContent: some View {
        Text("Choose your mode:")
            .font(.headline)

        // Quiz mode buttons
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(QuizMode.allCases, id: \.self) { mode in
                quizModeButton(mode)
            }
        }
        .padding(.horizontal)

        // AR Experiences Section
        VStack(alignment: .leading, spacing: 8) {
            Text("AR Experiences")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    arFeatureCard(
                        title: "Number Blocks",
                        icon: "cube.fill",
                        color: .blue,
                        destination: .arQuiz
                    )
                    arFeatureCard(
                        title: "Addition AR",
                        icon: "plus.circle.fill",
                        color: .green,
                        destination: .arAddition
                    )
                    arFeatureCard(
                        title: "Fractions",
                        icon: "circle.lefthalf.filled",
                        color: .orange,
                        destination: .arFractions
                    )
                    arFeatureCard(
                        title: "Place Value",
                        icon: "square.stack.3d.up.fill",
                        color: .purple,
                        destination: .arPlaceValue
                    )
                    arFeatureCard(
                        title: "Playground",
                        icon: "sparkles",
                        color: .pink,
                        destination: .arPlayground
                    )
                    arFeatureCard(
                        title: "Walk Around",
                        icon: "figure.walk",
                        color: .teal,
                        destination: .arWalkAround
                    )
                    arFeatureCard(
                        title: "Group Objects",
                        icon: "square.3.layers.3d",
                        color: .indigo,
                        destination: .arGrouping
                    )
                    arFeatureCard(
                        title: "Play Together",
                        icon: "person.2.fill",
                        color: .mint,
                        destination: .arCollaborative
                    )
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Elderly Content

    @ViewBuilder
    private var elderlyContent: some View {
        Text("Cognitive Exercises")
            .font(.headline)

        // Cognitive exercise button
        NavigationLink(value: AppDestination.cognitiveExercises) {
            HStack {
                Image(systemName: "brain.head.profile")
                VStack(alignment: .leading) {
                    Text("Brain Training")
                        .font(.headline)
                    Text("Memory, patterns, and word puzzles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color.teal.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .foregroundColor(.primary)

        // Basic math for cognitive maintenance
        Text("Math Practice")
            .font(.headline)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(QuizMode.allCases, id: \.self) { mode in
                quizModeButton(mode)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Bottom Navigation

    @ViewBuilder
    private var bottomNavigation: some View {
        Divider()
            .padding(.horizontal)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            NavigationLink(value: AppDestination.profile) {
                VStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.title3)
                    Text("Profile")
                        .font(.caption)
                }
            }
            NavigationLink(value: AppDestination.shop) {
                VStack(spacing: 4) {
                    Image(systemName: "cart")
                        .font(.title3)
                    Text("Shop")
                        .font(.caption)
                }
            }
            NavigationLink(value: AppDestination.parentDashboard) {
                VStack(spacing: 4) {
                    Image(systemName: "chart.bar")
                        .font(.title3)
                    Text("Dashboard")
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal)
        .foregroundColor(.primary)
    }

    // MARK: - Components

    private func quizModeButton(_ mode: QuizMode) -> some View {
        NavigationLink(value: AppDestination.quiz(mode)) {
            VStack(spacing: 4) {
                Text(mode.symbol)
                    .font(.largeTitle.bold())
                Text("Lv \(progressState.levelFor(mode: mode))")
                    .font(.caption)
                if mode.pointMultiplier > 1 {
                    Text("\(mode.pointMultiplier)x pts")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
        .foregroundColor(.primary)
    }

    private func arFeatureCard(title: String, icon: String, color: Color, destination: AppDestination) -> some View {
        NavigationLink(value: destination) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(width: 90, height: 80)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - XP Progress Bar

    @ViewBuilder
    private var xpProgressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let fraction = max(0, min(1, progressState.xpRequirements > 0
                    ? progressState.progress / CGFloat(progressState.xpRequirements) : 0))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 20)
                    RoundedRectangle(cornerRadius: 25)
                        .fill(progressState.progressColor.color)
                        .frame(width: geo.size.width * fraction, height: 20)
                }
            }
            .frame(height: 20)
            .padding(.horizontal)

            Text("\(Int(progressState.progress)) / \(progressState.xpRequirements) XP")
                .font(.caption)
                .foregroundColor(.secondary)
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
            AdditionSceneView()
            #else
            Text("AR requires iOS")
            #endif

        case .arFractions:
            #if os(iOS)
            FractionSceneView()
            #else
            Text("AR requires iOS")
            #endif

        case .arPlaceValue:
            #if os(iOS)
            PlaceValueSceneView()
            #else
            Text("AR requires iOS")
            #endif

        case .arPlayground:
            #if os(iOS)
            NumberPlaygroundSceneView()
            #else
            Text("AR requires iOS")
            #endif

        case .arWalkAround:
            #if os(iOS)
            WalkAroundSceneView()
            #else
            Text("AR requires iOS")
            #endif

        case .arGrouping:
            #if os(iOS)
            GroupingSceneView()
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
            CognitiveExerciseView(
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
                authService: authService,
                username: progressState.username
            )

        case .settings:
            Text("Settings")
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
            GeometryReader { geo in
                let fraction = max(0, min(1, progressState.xpRequirements > 0
                    ? progressState.progress / CGFloat(progressState.xpRequirements) : 0))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 40)
                    RoundedRectangle(cornerRadius: 25)
                        .fill(progressState.progressColor.color)
                        .frame(width: geo.size.width * fraction, height: 40)
                }
            }
            .frame(height: 40)

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
