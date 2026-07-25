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

    // Frosted-glass in-scene HUD (ForestView overlay only; the rest of the
    // app keeps the wood/parchment identity above).
    static let hudStamina = Color(hex: 0x4CD964)
    static let hudTextDark = Color(hex: 0x3A4046)
    static let hudPanelTint = Color.white.opacity(0.35)
    static let hudBorder = Color.white.opacity(0.6)
    static let hudTrack = Color.black.opacity(0.14)
    static let hudLogGold = Color(hex: 0xC79100)
    static let hudLogWarning = Color(hex: 0xC65A3F)
    static let hudBackground = Color(hex: 0xF4F6F2)

    /// Canonical palette for the 3D SceneKit forest. The 2D menu art in
    /// `Views/Art/TreeArt.swift` should migrate to these species colors as
    /// a follow-up so both stay in sync.
    enum Scene3D {
        static let grass = Color(hex: 0xA5CE4D)
        /// Fog color AND scene background — the two must stay identical so
        /// distant geometry fades seamlessly into the backdrop.
        static let haze = Color(hex: 0xE8F2D9)

        static let dirt = Color(hex: 0xD9A567)
        static let dirtLight = Color(hex: 0xE0B77E)
        static let rock = Color(hex: 0x9EA3A8)
        static let rockLight = Color(hex: 0xB6BBC0)
        static let pebble = Color(hex: 0xC9B18C)

        static let trunk = Color(hex: 0x8B5E3C)
        static let trunkDark = Color(hex: 0x6E4A2E)
        static let birchBark = Color(hex: 0xEDE7DA)
        static let birchBarkPatch = Color(hex: 0x5A5148)

        static let sunlight = Color(hex: 0xFFF4E0)
        static let ambient = Color(hex: 0xD7E8CE)

        // Player
        static let hatStraw = Color(hex: 0xE8C04A)
        static let hatBand = Color(hex: 0x8A6430)
        static let skin = Color(hex: 0xF3C99F)
        static let shirt = Color(hex: 0xF2EDDC)
        static let vest = Color(hex: 0x3E4A40)
        static let shorts = Color(hex: 0x4C7BC4)
        static let shoes = Color(hex: 0xE8A33D)

        /// Base + lighter highlight-facet pair for each species' canopy.
        static func canopy(for species: TreeSpecies) -> (base: Color, highlight: Color) {
            switch species {
            case .birch: return (Color(hex: 0x8CCB57), Color(hex: 0xA8DE74))
            case .oak: return (Color(hex: 0x63B446), Color(hex: 0x82CC61))
            case .willow: return (Color(hex: 0x97C34E), Color(hex: 0xBADC70))
            case .evergreen: return (Color(hex: 0x3F9147), Color(hex: 0x57A75B))
            case .ancientYew: return (Color(hex: 0x2E7D46), Color(hex: 0x46985C))
            case .elderwood: return (Color(hex: 0x7B68B8), Color(hex: 0x9C8AD6))
            }
        }

        static func trunkColor(for species: TreeSpecies) -> Color {
            switch species {
            case .birch: return birchBark
            case .oak, .willow: return trunk
            case .evergreen, .ancientYew: return trunkDark
            case .elderwood: return Color(hex: 0x4C3A55)
            }
        }

        /// Willow's hanging fronds are a lighter yellow-green than its cap.
        static let willowFrond = Color(hex: 0xA9CE58)

        /// Minimap dot = the species' canopy base color.
        static func minimapDot(for species: TreeSpecies) -> Color {
            canopy(for: species).base
        }
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
