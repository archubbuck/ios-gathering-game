import SwiftUI

/// The redesign's six-token theme object (design handoff §"Design system
/// summary" / Decision 8 of DESIGN_RATIONALE.md): every screen re-skins from
/// exactly these six colors, selected as one unit in Settings → Theme color.
/// Never hardcode a screen's colors — read them from `ThemeStore.theme`.
struct AppTheme: Equatable {
    let g1: Color
    let g2: Color
    let accent: Color
    let soft: Color
    let chip: Color
    let bg: Color

    /// The 135°ish hero/avatar/sparkline gradient shared by every screen.
    var heroGradient: LinearGradient {
        LinearGradient(colors: [g1, g2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum Palette: String, CaseIterable, Identifiable, Codable {
    case blueberry, bubblegum, meadow, sunset, grape

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blueberry: return "Blueberry"
        case .bubblegum: return "Bubblegum"
        case .meadow: return "Meadow"
        case .sunset: return "Sunset"
        case .grape: return "Grape"
        }
    }

    // Hex values straight from the handoff's palette table.
    var theme: AppTheme {
        switch self {
        case .blueberry:
            return AppTheme(
                g1: Color(hex: 0x3b6bff), g2: Color(hex: 0x7a5cff),
                accent: Color(hex: 0x2b5bd7), soft: Color(hex: 0xf2f5ff),
                chip: Color(hex: 0xeaf0ff), bg: Color(hex: 0xeef1fb)
            )
        case .bubblegum:
            return AppTheme(
                g1: Color(hex: 0xff5fa2), g2: Color(hex: 0xff8fca),
                accent: Color(hex: 0xd63384), soft: Color(hex: 0xfff2f8),
                chip: Color(hex: 0xffe3f0), bg: Color(hex: 0xfdeef5)
            )
        case .meadow:
            return AppTheme(
                g1: Color(hex: 0x1eb47f), g2: Color(hex: 0x57d29f),
                accent: Color(hex: 0x0f8a5f), soft: Color(hex: 0xedfaf4),
                chip: Color(hex: 0xd5f2e5), bg: Color(hex: 0xeaf7f1)
            )
        case .sunset:
            return AppTheme(
                g1: Color(hex: 0xff7a45), g2: Color(hex: 0xffa25c),
                accent: Color(hex: 0xd9502a), soft: Color(hex: 0xfff2ec),
                chip: Color(hex: 0xffe1d4), bg: Color(hex: 0xfdefe8)
            )
        case .grape:
            return AppTheme(
                g1: Color(hex: 0x8b5cf6), g2: Color(hex: 0xb06cff),
                accent: Color(hex: 0x7a3ff0), soft: Color(hex: 0xf5f0ff),
                chip: Color(hex: 0xebe1ff), bg: Color(hex: 0xf3eefd)
            )
        }
    }
}

extension AppTheme {
    // Fixed (non-theme) colors — identical across every palette, per the
    // handoff's "Fixed (non-theme) colors" list.
    static let textPrimary = Color(hex: 0x191d2b)
    static let textSecondary = Color(hex: 0x7b83a3)
    static let textTertiary = Color(hex: 0xa4abc4)
    static let bodyPrimary = Color(hex: 0x3b4258)
    static let bodySecondary = Color(hex: 0x5f6785)
    static let cardSurface = Color.white
    static let hairline = Color(red: 30.0 / 255, green: 40.0 / 255, blue: 80.0 / 255).opacity(0.07)
    static let trendUp = Color(hex: 0x1eb47f)
    static let trendDown = Color(hex: 0xe0603a)
    static let trendSteady = Color(hex: 0x9aa2b8)
    static let liveDot = Color(hex: 0x1eb47f)
    static let destructive = Color(hex: 0xe0603a)
    static let toggleOffTrack = Color(hex: 0xdfe3ef)

    static func trendColor(for trend: PopularityTrend?) -> Color {
        switch trend {
        case .up: return trendUp
        case .down: return trendDown
        case .flat, .none: return trendSteady
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
