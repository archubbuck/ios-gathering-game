import SwiftUI

/// Detects whether the app was launched with `--screenshots` (set by
/// CI). When true, the app renders a screenshot catalog — no sign-in,
/// no network, no real stores involved.
private let isScreenshotMode: Bool = {
    CommandLine.arguments.contains("--screenshots")
}()

@main
struct iOSFullStackStarterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var pushManager = PushNotificationManager.shared
    @StateObject private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            if isScreenshotMode {
                ScreenshotCatalogView()
            } else {
                RootView()
                    .environmentObject(sessionStore)
                    .environmentObject(pushManager)
                    .environmentObject(themeStore)
                    .preferredColorScheme(themeStore.appearance.colorScheme)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            guard !isScreenshotMode else { return }
            switch newPhase {
            case .active:
                AnalyticsQueue.shared.record(eventType: "session_start")
            case .background:
                AnalyticsQueue.shared.record(eventType: "session_end")
                AnalyticsQueue.shared.flush()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
