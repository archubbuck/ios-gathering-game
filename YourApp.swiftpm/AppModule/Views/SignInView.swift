import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Your App Name")
                    .font(.system(.largeTitle, weight: .bold))
                Text("Sign in to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Sign in with Apple is disabled for now (needs an entitlement
            // that isn't configured yet — §0.1). Device-identified sign-in
            // needs no user interaction, so it just runs on appear below;
            // this button only shows up if that attempt failed.
            if sessionStore.isAuthenticating {
                ProgressView()
            } else if sessionStore.authErrorMessage != nil {
                Button("Try Again") {
                    Task { await sessionStore.signInWithDevice() }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
            }

            if let message = sessionStore.authErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .task {
            await sessionStore.signInWithDevice()
        }
    }
}
