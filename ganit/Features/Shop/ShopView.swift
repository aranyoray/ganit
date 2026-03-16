import SwiftUI

// MARK: - Shop View

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
                    Button {
                        purchase(item)
                    } label: {
                        HStack {
                            Text(item.name)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(item.cost) pts -> \(item.reward) coins")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(progressState.score >= item.cost
                            ? Color.blue.opacity(0.1)
                            : Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .disabled(progressState.score < item.cost)
                }

                // Purchase feedback
                if let reward = lastReward, let name = lastPurchaseName {
                    Text("You got \(reward) coins from \(name)!")
                        .font(.callout.bold())
                        .foregroundColor(.green)
                }
            }
            .padding()
        }
        .navigationTitle("Shop")
    }

    private func purchase(_ item: ShopItem) {
        guard progressState.score >= item.cost else { return }
        progressState.score -= item.cost
        progressState.coins += item.reward
        lastReward = item.reward
        lastPurchaseName = item.name
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
        ShopItem(id: "common", name: "Common Reward", description: "50 coins", cost: 25, reward: 50, isRandom: false),
        ShopItem(id: "rare", name: "Rare Reward", description: "100 coins", cost: 50, reward: 100, isRandom: false),
        ShopItem(id: "epic", name: "Epic Reward", description: "250 coins", cost: 100, reward: 250, isRandom: false),
        ShopItem(id: "mythic", name: "Mythic Reward", description: "500 coins", cost: 150, reward: 500, isRandom: false),
        ShopItem(id: "legendary", name: "Legendary Reward", description: "1000 coins", cost: 250, reward: 1000, isRandom: false),
    ]
}
