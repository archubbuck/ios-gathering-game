import AuthenticationServices
import Foundation
import UIKit

/// Owns sign-in state for the whole app. `APIClient.shared.tokenProvider` is
/// wired to read `accessToken` here, so once a token is set every other
/// view model's requests are authenticated automatically.
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var userId: UUID?
    @Published private(set) var isSignedIn = false
    @Published var isAuthenticating = false
    @Published var authErrorMessage: String?

    private var accessToken: String? {
        didSet { isSignedIn = accessToken != nil }
    }

    init() {
        APIClient.shared.tokenProvider = { [weak self] in self?.accessToken }
        if let savedToken = KeychainTokenStore.load() {
            accessToken = savedToken
            // userId isn't persisted separately — it's re-derived from the
            // next successful call, or re-established on the next sign-in.
            // For a fully offline-safe restore we'd decode the JWT locally;
            // deferred since the client never needs to read its own claims.
            isSignedIn = true
        }
    }

    /// Sign in with Apple is disabled for now — it needs the
    /// com.apple.developer.applesignin entitlement, which isn't configured
    /// yet (§0.1 of the implementation plan). This identifies the user by
    /// `UIDevice.identifierForVendor` instead: a UUID iOS hands out per
    /// app-vendor per device, with no entitlement, permission prompt, or
    /// user interaction required. Trade-off: unlike Sign in with Apple this
    /// doesn't carry across devices/reinstalls (see §3.17), and the server
    /// can't cryptographically verify it — accepted for now to unblock
    /// testing; `handleAppleAuthorization` below is left in place to make
    /// switching back a client-only change once the entitlement is set up.
    func signInWithDevice() async {
        authErrorMessage = nil

        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else {
            authErrorMessage = "Couldn't determine a device identifier."
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let response = try await APIClient.shared.signInWithDevice(deviceId: deviceId)
            accessToken = response.accessToken
            userId = response.userId
            KeychainTokenStore.save(response.accessToken)
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    /// Called from `SignInWithAppleButton`'s `onCompletion` — SwiftUI's
    /// button already drives the `ASAuthorizationController` flow, so this
    /// only needs to unwrap the identity token and exchange it server-side.
    /// Currently unused — see `signInWithDevice()` above.
    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) async {
        authErrorMessage = nil

        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            authErrorMessage = error.localizedDescription

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                authErrorMessage = "Apple didn't return a usable identity token."
                return
            }

            isAuthenticating = true
            defer { isAuthenticating = false }

            do {
                let response = try await APIClient.shared.signInWithApple(identityToken: identityToken)
                accessToken = response.accessToken
                userId = response.userId
                KeychainTokenStore.save(response.accessToken)
            } catch {
                authErrorMessage = error.localizedDescription
            }
        }
    }

    func signOut() {
        accessToken = nil
        userId = nil
        KeychainTokenStore.clear()
    }
}
