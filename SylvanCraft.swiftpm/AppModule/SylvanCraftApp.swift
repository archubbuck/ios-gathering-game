import SwiftUI

@main
struct SylvanCraftApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var settings = SettingsStore()
    @StateObject private var game = GameState()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(settings)
                .environmentObject(game)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                game.stopChopping()
                game.saveNow()
            }
        }
    }
}
