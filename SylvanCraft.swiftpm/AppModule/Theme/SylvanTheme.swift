import SwiftUI

/// Sylvan Craft's single visual identity: medieval-fantasy vector art on
/// parchment and dark wood. All colors come from here — never hardcode a
/// hex in a view.
enum SylvanTheme {
    // Brand palette (PRD design tokens)
    static let darkWood = Color(hex: 0x3E2723)
    static let forestGreen = Color(hex: 0x2E7D32)
    static let gold = Color(hex: 0xFFC107)

    // Surfaces
    static let parchment = Color(hex: 0xF3E5C0)
    static let parchmentLight = Color(hex: 0xF9F0DA)
    static let parchmentEdge = Color(hex: 0xD8C08F)
    static let woodPanelTop = Color(hex: 0x4E342E)
    static let woodPanelBottom = Color(hex: 0x321F1B)

    // Nature tones for scene art
    static let bark = Color(hex: 0x5D4037)
    static let barkLight = Color(hex: 0x795548)
    static let canopyLight = Color(hex: 0x66BB6A)
    static let canopyDark = Color(hex: 0x1B5E20)
    static let groundLight = Color(hex: 0x8BC34A)
    static let groundDark = Color(hex: 0x558B2F)
    static let skyTop = Color(hex: 0xB3E5FC)
    static let skyBottom = Color(hex: 0xE1F5FE)

    // Text
    static let textOnParchment = Color(hex: 0x3E2C1C)
    static let textOnParchmentSecondary = Color(hex: 0x7A6547)
    static let textOnWood = Color(hex: 0xF3E5C0)

    // Semantic
    static let success = Color(hex: 0x2E7D32)
    static let destructive = Color(hex: 0xC62828)
    static let locked = Color(hex: 0x9E9E9E)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [forestGreen, canopyDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
