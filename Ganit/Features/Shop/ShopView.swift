import SwiftUI

// MARK: - Shop View

/// Cleaned up from ganit_base/Shop.swift. Fixed pricing bugs.
struct ShopView: View {
    @ObservedObject var progressState: ProgressState
    @State private var lastReward: Int?
    @State private var lastPurchaseName: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Balance header
                HStack {
                    Label("\(progressState.score) Points", systemImage: "star.fill")
                        .foregroundColor(.orange)
                    Spacer()
                    Label("\(progressState.coins) Coins", systemImage: "bitcoinsign.circle.fill")
                        .foregroundColor(.yellow)
                }
                .font(.headline)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                // Shop items
                ForEach(ShopItem.allItems) { item in
                    shopItemRow(item)
                }

                // Purchase feedback
                if let reward = lastReward, let name = lastPurchaseName {
                    Text("You got \(reward) coins from \(name)!")
                        .font(.callout.bold())
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle("Shop")
    }

    @ViewBuilder
    private func shopItemRow(_ item: ShopItem) -> some View {
        Button {
            purchase(item)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(item.cost) pts")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                    Text("\(item.reward) coins")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                progressState.score >= item.cost
                    ? Color.blue.opacity(0.1)
                    : Color.gray.opacity(0.1)
            )
            .cornerRadius(10)
        }
        .disabled(progressState.score < item.cost)
    }

    private func purchase(_ item: ShopItem) {
        guard progressState.score >= item.cost else { return }

        let reward: Int
        if item.isRandom {
            reward = rollRandomReward()
        } else {
            reward = item.reward
        }

        progressState.score -= item.cost
        progressState.coins += reward
        lastReward = reward
        lastPurchaseName = item.name
        HapticManager.success()
    }

    private func rollRandomReward() -> Int {
        let roll = Int.random(in: 1...500)
        switch roll {
        case 1...5:     return 1000  // Legendary (1%)
        case 6...45:    return 500   // Mythic (8%)
        case 46...135:  return 250   // Epic (18%)
        case 136...275: return 100   // Rare (28%)
        default:        return 50    // Common (45%)
        }
    }
}

// MARK: - Shop Item Model

struct ShopItem: Identifiable {
    let id: String
    let name: String
    let description: String
    let cost: Int
    let reward: Int
    let isRandom: Bool

    static let allItems: [ShopItem] = [
        ShopItem(id: "random", name: "Mystery Reward", description: "1% Legendary, 8% Mythic, 18% Epic, 28% Rare, 45% Common", cost: 30, reward: 0, isRandom: true),
        ShopItem(id: "common", name: "Common Reward", description: "Guaranteed 50 coins", cost: 25, reward: 50, isRandom: false),
        ShopItem(id: "rare", name: "Rare Reward", description: "Guaranteed 100 coins", cost: 50, reward: 100, isRandom: false),
        ShopItem(id: "epic", name: "Epic Reward", description: "Guaranteed 250 coins", cost: 100, reward: 250, isRandom: false),
        ShopItem(id: "mythic", name: "Mythic Reward", description: "Guaranteed 500 coins", cost: 150, reward: 500, isRandom: false),
        ShopItem(id: "legendary", name: "Legendary Reward", description: "Guaranteed 1000 coins", cost: 250, reward: 1000, isRandom: false),
    ]
}
