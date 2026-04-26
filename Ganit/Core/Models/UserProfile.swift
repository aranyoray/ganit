import Foundation
import SwiftUI

// MARK: - User Group

enum UserGroup: String, Codable {
    case child
    case elderly
}

// MARK: - User Profile

struct UserProfile: Codable {
    let id: UUID
    var username: String
    var userGroup: UserGroup
    var age: Int?
    var parentEmail: String?
    var consentGranted: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        username: String,
        userGroup: UserGroup,
        age: Int? = nil,
        parentEmail: String? = nil,
        consentGranted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.username = username
        self.userGroup = userGroup
        self.age = age
        self.parentEmail = parentEmail
        self.consentGranted = consentGranted
        self.createdAt = createdAt
    }
}

// MARK: - Progress State

/// Holds all gamification/progression state, extracted from the old AppData monolith.
@MainActor
class ProgressState: ObservableObject {
    private var isBatchUpdating = false
    private let storage: StorageProvider
    private(set) var username: String = ""

    @Published var score: Int = 0                  { didSet { saveIfReady("score", score) } }
    @Published var additionLevel: Int = 0          { didSet { saveIfReady("AdditionLevel", additionLevel) } }
    @Published var subtractionLevel: Int = 0       { didSet { saveIfReady("SubtractionLevel", subtractionLevel) } }
    @Published var multiplicationLevel: Int = 0    { didSet { saveIfReady("MultiplicationLevel", multiplicationLevel) } }
    @Published var divisionLevel: Int = 0          { didSet { saveIfReady("DivisionLevel", divisionLevel) } }
    @Published var progress: CGFloat = 0           { didSet { saveIfReady("progress", progress) } }
    @Published var xpRequirements: Int = 1000      { didSet { saveIfReady("XPRequirements", xpRequirements) } }
    @Published var coins: Int = 50                 { didSet { saveIfReady("Coins", coins) } }
    @Published var shows: Int = 0                  { didSet { saveIfReady("shows", shows) } }
    @Published var vipShows: Int = 0               { didSet { saveIfReady("vipshows", vipShows) } }
    @Published var powerUpPointLevel: Int = 1      { didSet { saveIfReady("powerUpPointLevel", powerUpPointLevel) } }
    @Published var onWhichLevel: Int = 0           { didSet { saveIfReady("onWhichLevel", onWhichLevel) } }
    @Published var characterList: [String] = []    {
        didSet {
            guard !isBatchUpdating, !username.isEmpty else { return }
            storage.saveCodable("characterList", value: characterList, user: username)
        }
    }

    // Color progression: white → red → orange → yellow → green → blue → black
    @Published var progressColor: ProgressColor = .white { didSet { saveIfReady("color", progressColor.rawValue) } }

    init(storage: StorageProvider) {
        self.storage = storage
    }

    private func saveIfReady(_ key: String, _ value: Any) {
        guard !isBatchUpdating, !username.isEmpty else { return }
        storage.save(key, value: "\(value)", user: username)
    }

    func setUser(_ newUsername: String) {
        guard username != newUsername else { return }
        username = newUsername
        loadAll()
    }

    func levelFor(mode: QuizMode) -> Int {
        switch mode {
        case .addition:       return additionLevel
        case .subtraction:    return subtractionLevel
        case .multiplication: return multiplicationLevel
        case .division:       return divisionLevel
        }
    }

    func incrementLevel(for mode: QuizMode) {
        switch mode {
        case .addition:       additionLevel += 1
        case .subtraction:    subtractionLevel += 1
        case .multiplication: multiplicationLevel += 1
        case .division:       divisionLevel += 1
        }
    }

    func advanceLevel() {
        progress -= CGFloat(xpRequirements)
        xpRequirements += 500
        switch progressColor {
        case .white:  progressColor = .red
        case .red:    progressColor = .orange;  xpRequirements += 50
        case .orange: progressColor = .yellow;  xpRequirements += 100
        case .yellow: progressColor = .green;   xpRequirements += 200
        case .green:  progressColor = .blue;    xpRequirements += 300
        case .blue:   progressColor = .black;   xpRequirements += 500
        case .black:  break
        }
    }

    func resetAll() {
        isBatchUpdating = true
        score = 0
        additionLevel = 0
        subtractionLevel = 0
        multiplicationLevel = 0
        divisionLevel = 0
        progress = 0
        xpRequirements = 1000
        progressColor = .white
        coins = 0
        shows = 0
        vipShows = 0
        powerUpPointLevel = 1
        onWhichLevel = 0
        characterList = []

        let user = username
        storage.save("score", value: "0", user: user)
        storage.save("AdditionLevel", value: "0", user: user)
        storage.save("SubtractionLevel", value: "0", user: user)
        storage.save("MultiplicationLevel", value: "0", user: user)
        storage.save("DivisionLevel", value: "0", user: user)
        storage.save("progress", value: "0.0", user: user)
        storage.save("XPRequirements", value: "1000", user: user)
        storage.save("color", value: "white", user: user)
        storage.save("Coins", value: "0", user: user)
        storage.save("shows", value: "0", user: user)
        storage.save("vipshows", value: "0", user: user)
        storage.save("powerUpPointLevel", value: "1", user: user)
        storage.save("onWhichLevel", value: "0", user: user)
        storage.saveCodable("characterList", value: [String](), user: user)
        isBatchUpdating = false
    }

    private func loadAll() {
        let user = username
        isBatchUpdating = true
        additionLevel       = Int(storage.read("AdditionLevel", user: user))       ?? 0
        subtractionLevel    = Int(storage.read("SubtractionLevel", user: user))    ?? 0
        multiplicationLevel = Int(storage.read("MultiplicationLevel", user: user)) ?? 0
        divisionLevel       = Int(storage.read("DivisionLevel", user: user))       ?? 0
        progress            = CGFloat(Double(storage.read("progress", user: user)) ?? 0)
        xpRequirements      = Int(storage.read("XPRequirements", user: user))      ?? 1000
        progressColor       = ProgressColor(rawValue: storage.read("color", user: user).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .white
        score               = Int(storage.read("score", user: user))               ?? 0
        coins               = Int(storage.read("Coins", user: user))               ?? 50
        characterList       = storage.readCodable("characterList", as: [String].self, user: user) ?? []
        onWhichLevel        = Int(storage.read("onWhichLevel", user: user))        ?? 0
        powerUpPointLevel   = Int(storage.read("powerUpPointLevel", user: user))   ?? 1
        shows               = Int(storage.read("shows", user: user))               ?? 0
        vipShows            = Int(storage.read("vipshows", user: user))            ?? 0
        isBatchUpdating = false
    }
}

// MARK: - Progress Color

enum ProgressColor: String, Codable {
    case white, red, orange, yellow, green, blue, black

    var color: Color {
        switch self {
        case .white:  return .white
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .black:  return .black
        }
    }
}

// MARK: - Quiz Mode

enum QuizMode: String, Codable, CaseIterable {
    case addition
    case subtraction
    case multiplication
    case division

    var symbol: String {
        switch self {
        case .addition:       return "+"
        case .subtraction:    return "-"
        case .multiplication: return "*"
        case .division:       return "/"
        }
    }

    var displayName: String {
        rawValue.capitalized
    }

    var pointMultiplier: Int {
        switch self {
        case .addition:       return 1
        case .subtraction:    return 2
        case .division:       return 3
        case .multiplication: return 5
        }
    }

    var xpReward: CGFloat {
        switch self {
        case .addition:       return 50
        case .subtraction:    return 100
        case .division:       return 150
        case .multiplication: return 250
        }
    }

    var topic: String { rawValue }

    init?(from symbol: String) {
        switch symbol {
        case "+": self = .addition
        case "-": self = .subtraction
        case "*": self = .multiplication
        case "/": self = .division
        default: return nil
        }
    }
}
