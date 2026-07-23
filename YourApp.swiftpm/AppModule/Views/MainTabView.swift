import SwiftUI

/// Simplified tab-based root navigation for the template.
/// Replace with your own tab structure — this demonstrates the pattern
/// of using `SessionStore` to gate on auth state and `themeStore` for
/// appearance.
struct MainTabView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var pushManager: PushNotificationManager
    @EnvironmentObject private var themeStore: ThemeStore
    @State private var selectedTab: AppTab = .items

    var body: some View {
        TabView(selection: $selectedTab) {
            ItemsView()
                .tabItem {
                    Label("Items", systemImage: "list.bullet")
                }
                .tag(AppTab.items)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
    }
}

enum AppTab: Hashable {
    case items
    case settings
}

            }
            .foregroundStyle(AppTheme.textPrimary)
        }
        .sheet(isPresented: $isCreatingNewDeck) {
            CreateDeckView()
        }
        .sheet(isPresented: $isJoiningDeck) {
            JoinDeckView()
        }
    }
}
