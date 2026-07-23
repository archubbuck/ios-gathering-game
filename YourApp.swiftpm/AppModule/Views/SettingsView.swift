import SwiftUI

/// Template settings screen. Replace with your own settings UI.
/// Demonstrates sign-out via `SessionStore` and theme toggling via
/// `ThemeStore` — the two infrastructure stores every app built from this
/// template starts with.
struct SettingsView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $themeStore.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                }

                Section("Account") {
                    Button("Sign Out", role: .destructive) {
                        KeychainTokenStore.clear()
                        sessionStore.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

