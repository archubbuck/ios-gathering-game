import SwiftUI

@main
struct SylvanCraftApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var settings = SettingsStore()
    @StateObject private var game = GameState()
    @StateObject private var engine = ChopEngine()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(settings)
                .environmentObject(game)
                .preferredColorScheme(settings.appearance.colorScheme)
                .task { engine.attach(to: game) }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                game.stopChopping()
                game.saveNow()
            }
        }
    }
}
