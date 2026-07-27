import SwiftUI

enum AppTab: Hashable {
    case forest
    case pack
    case shop
    case profile
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .forest

    var body: some View {
        TabView(selection: $selectedTab) {
            ForestView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.forest)

            PackView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.pack)

            ShopView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.shop)

            ProfileView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.profile)
        }
        .tint(SylvanTheme.forestGreen)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavBar(selection: $selectedTab)
        }
    }
}
