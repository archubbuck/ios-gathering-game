import SwiftUI

/// Settings → Appearance → Light/Dark/System, applied app-wide via
/// `.preferredColorScheme` in the app entry point.
enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Client-only preferences, persisted to UserDefaults. Game progress lives
/// in GameState/SaveManager, not here.
@MainActor
final class SettingsStore: ObservableObject {
    @Published var appearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
        }
    }

    @Published var hapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticsEnabled, forKey: Self.hapticsKey)
        }
    }

    private static let appearanceKey = "selectedAppearanceMode"
    private static let hapticsKey = "hapticsEnabled"

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.appearanceKey),
            let appearance = AppearanceMode(rawValue: saved)
        {
            self.appearance = appearance
        } else {
            self.appearance = .system
        }

        self.hapticsEnabled = UserDefaults.standard.object(forKey: Self.hapticsKey) as? Bool ?? true
    }
}
