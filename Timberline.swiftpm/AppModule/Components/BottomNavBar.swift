import SwiftUI

/// Themed replacement for the system tab bar chrome, giving exact control
/// over icon/label padding instead of inheriting default system insets
/// (which read as uneven whitespace against the rest of the app's tight,
/// custom-styled wood/parchment chrome).
struct BottomNavBar: View {
    @Binding var selection: AppTab

    private struct Item {
        let tab: AppTab
        let systemImage: String
        let title: String
    }

    private let items: [Item] = [
        Item(tab: .forest, systemImage: "tree", title: "Forest"),
        Item(tab: .pack, systemImage: "backpack", title: "Pack"),
        Item(tab: .shop, systemImage: "cart", title: "Shop"),
        Item(tab: .profile, systemImage: "person", title: "Profile"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                Button {
                    selection = item.tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                        Text(item.title)
                            .font(.stat(11, weight: .semibold))
                    }
                    .foregroundStyle(selection == item.tab ? TimberlineTheme.gold : TimberlineTheme.textOnWood.opacity(0.55))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            LinearGradient(
                colors: [TimberlineTheme.woodPanelTop, TimberlineTheme.woodPanelBottom],
                startPoint: .top, endPoint: .bottom
            )
            .overlay(Rectangle().fill(TimberlineTheme.darkWood).frame(height: 1), alignment: .top)
            .ignoresSafeArea(edges: .bottom)
        )
    }
}
