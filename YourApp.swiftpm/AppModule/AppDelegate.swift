import UIKit

/// Bridges the one UIKit-only callback SwiftUI's App lifecycle doesn't
/// expose a hook for: the APNs device token callback (§2.8, §3.1). Nothing
/// else about the app lives here — everything else stays in SwiftUI/App.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // No actionable recovery — the user simply won't receive push
        // until a future launch succeeds in registering.
    }
}
