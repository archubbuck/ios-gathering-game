import SwiftUI

enum AppTab: Hashable {
    case forest
    case pack
    case map
    case shop
    case profile
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .forest

    var body: some View {
        TabView(selection: $selectedTab) {
            DebugCoreView()
                .tabItem { Label("Forest", systemImage: "tree") }
                .tag(AppTab.forest)

            PlaceholderScreen(title: "Pack", subtitle: "Inventory & bank")
                .tabItem { Label("Pack", systemImage: "backpack") }
                .tag(AppTab.pack)

            PlaceholderScreen(title: "World Map", subtitle: "Travel between regions")
                .tabItem { Label("Map", systemImage: "map") }
                .tag(AppTab.map)

            PlaceholderScreen(title: "Axe Shop", subtitle: "Bronze to Dragon")
                .tabItem { Label("Shop", systemImage: "cart") }
                .tag(AppTab.shop)

            PlaceholderScreen(title: "Profile", subtitle: "Skills & achievements")
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(AppTab.profile)
        }
        .tint(SylvanTheme.forestGreen)
    }
}

/// Temporary stand-in until each tab's real screen lands in later phases.
struct PlaceholderScreen: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            SylvanTheme.parchment.ignoresSafeArea()
            VStack(spacing: 12) {
                Text(title)
                    .font(.display(34))
                    .foregroundStyle(SylvanTheme.textOnParchment)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(SylvanTheme.textOnParchmentSecondary)
            }
        }
    }
}

/// Phase 1 scaffolding: exercises GameState end-to-end (chop ticks, XP,
/// gold, selling, persistence) before the real forest screen exists.
/// Replaced by ForestView in Phase 2.
struct DebugCoreView: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        ZStack {
            SylvanTheme.parchment.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(game.region.name)
                    .font(.display(28))
                    .foregroundStyle(SylvanTheme.textOnParchment)

                let progress = XPTable.progressToNext(xp: game.totalXP)
                VStack(spacing: 4) {
                    Text("Level \(game.level)")
                        .font(.display(22))
                    ProgressView(value: progress.fraction)
                        .tint(SylvanTheme.forestGreen)
                    Text("\(Int(game.totalXP)) XP · \(game.gold) gp · pack \(game.packCount)/28")
                        .font(.stat(15))
                }
                .foregroundStyle(SylvanTheme.textOnParchment)
                .padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(game.trees) { tree in
                        Button {
                            game.tapTree(tree.id)
                        } label: {
                            HStack {
                                Text(tree.species.displayName)
                                Spacer()
                                if game.activeChopTreeID == tree.id {
                                    Text("chopping...")
                                } else if tree.isDepleted {
                                    Text("regrowing")
                                } else {
                                    Text("\(tree.logsRemaining) logs")
                                }
                            }
                            .font(.stat(15))
                            .padding(10)
                            .background(SylvanTheme.parchmentLight, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)

                HStack(spacing: 12) {
                    Button("Tick") { game.performChopTick() }
                    Button("Sell all") { game.sellAllLogs() }
                    Button("+500 XP") { game.debugAddXP(500) }
                    Button("+100 gp") { game.debugAddGold(100) }
                }
                .buttonStyle(.borderedProminent)
                .tint(SylvanTheme.forestGreen)
                .font(.stat(13))

                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(game.eventLog.suffix(8).reversed()) { entry in
                            Text(entry.text)
                                .font(.stat(12, weight: .regular))
                                .foregroundStyle(SylvanTheme.textOnParchmentSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)
                .padding(.horizontal, 32)
            }
            .padding(.vertical)
        }
    }
}
