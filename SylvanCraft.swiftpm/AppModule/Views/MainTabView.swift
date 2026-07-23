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
            ForestView()
                .tabItem { Label("Forest", systemImage: "tree") }
                .tag(AppTab.forest)

            PackView()
                .tabItem { Label("Pack", systemImage: "backpack") }
                .tag(AppTab.pack)

            MapView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(AppTab.map)

            ShopView()
                .tabItem { Label("Shop", systemImage: "cart") }
                .tag(AppTab.shop)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(AppTab.profile)
        }
        .tint(SylvanTheme.forestGreen)
    }
}
