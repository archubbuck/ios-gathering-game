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
            PlaceholderScreen(title: "Forest", subtitle: "Chop trees, gain XP")
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
