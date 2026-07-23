import SwiftUI

/// Root view: gates on auth state. Signed-out users see SignInView;
/// signed-in users see MainTabView. Push registration fires on sign-in.
/// Replace MainTabView with your own root navigation.
struct RootView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var pushManager: PushNotificationManager

    var body: some View {
        Group {
            if sessionStore.isSignedIn {
                MainTabView()
                    .task {
                        await pushManager.requestAuthorizationAndRegister()
                    }
            } else {
                SignInView()
            }
        }
    }
}
