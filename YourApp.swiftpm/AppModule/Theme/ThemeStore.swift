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

/// Settings → Theme color (Decision 8): a single palette choice drives every
/// screen's colors at once. Persisted the same way `DeckStore` persists the
/// last-active deck — plain `UserDefaults`, no server round-trip, since this
/// is purely a client preference.
@MainActor
final class ThemeStore: ObservableObject {
    @Published var palette: Palette {
        didSet {
            UserDefaults.standard.set(palette.rawValue, forKey: Self.paletteKey)
        }
    }

    @Published var appearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
        }
    }

    private static let paletteKey = "selectedThemePalette"
    private static let appearanceKey = "selectedAppearanceMode"

    var theme: AppTheme { palette.theme }

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.paletteKey),
            let palette = Palette(rawValue: saved)
        {
            self.palette = palette
        } else {
            self.palette = .blueberry
        }

        if let saved = UserDefaults.standard.string(forKey: Self.appearanceKey),
            let appearance = AppearanceMode(rawValue: saved)
        {
            self.appearance = appearance
        } else {
            self.appearance = .system
        }
    }
}
