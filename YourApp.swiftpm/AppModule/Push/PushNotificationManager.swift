import Foundation
import UIKit
import UserNotifications

/// Device push registration (§2.8, §3.1, §3.8). Requesting the system
/// permission and registering the resulting APNs token with the backend is
/// what actually lets Mutual Match and weekly digest pushes reach this
/// device — without it, `device_tokens` never gets a row for this user, and
/// the backend (which is fully wired up to send) has nothing to send to.
///
/// Push Notifications is an entitlement-requiring capability Swift
/// Playgrounds can't configure on its own (§0.1) — this code is inert until
/// that entitlement is added once via Xcode.
@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    /// Set when the user taps a push notification; consumed by
    /// `MainTabView` to deep-link into the right deck/tab (§3.1, §3.8).
    @Published var pendingDeepLink: PushDeepLink?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Safe to call every time the signed-in root view appears — the OS
    /// no-ops a repeat authorization request, and re-registering an
    /// unchanged token is a harmless upsert server-side (this also keeps
    /// the stored timezone fresh if the user has traveled since last
    /// launch, since §3.8's digest targeting depends on it).
    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task {
            try? await APIClient.shared.registerDevice(
                token: token,
                environment: Self.apnsEnvironment,
                timezone: TimeZone.current.identifier
            )
        }
    }

    // Parsing the provisioning profile's aps-environment entry at runtime
    // is more machinery than this needs — the standard simplification is a
    // compile-time split: Debug builds always run under the sandbox APNs
    // environment, Release (TestFlight/App Store) builds under production.
    private static var apnsEnvironment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }
}

struct PushDeepLink: Equatable {
    let deckId: UUID
    let type: String // "mutual_match" (§3.1) | "weekly_digest" (§3.8)
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Deep link on tap (§3.1, §3.8): both notification payloads carry
    // `deck_id` + `type` in their data dictionary.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if
            let deckIdString = userInfo["deck_id"] as? String,
            let deckId = UUID(uuidString: deckIdString),
            let type = userInfo["type"] as? String
        {
            Task { @MainActor in
                PushNotificationManager.shared.pendingDeepLink = PushDeepLink(deckId: deckId, type: type)
            }
        }
        completionHandler()
    }
}
