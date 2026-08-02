import SwiftUI

/// A cut log, tinted per species.
struct LogIcon: View {
    let species: TreeSpecies

    var body: some View {
        let tint = LogIcon.barkColor(for: species)
        ZStack {
            Capsule()
                .fill(tint)
                .overlay(Capsule().stroke(TimberlineTheme.darkWood.opacity(0.5), lineWidth: 1.2))
                .frame(width: 36, height: 17)
            Ellipse()
                .fill(TimberlineTheme.parchmentLight)
                .overlay(Ellipse().stroke(TimberlineTheme.darkWood.opacity(0.5), lineWidth: 1))
                .frame(width: 11, height: 15)
                .offset(x: -12.5)
            Ellipse()
                .stroke(tint.opacity(0.8), lineWidth: 1.2)
                .frame(width: 5, height: 8)
                .offset(x: -12.5)
        }
        .frame(width: 40, height: 22)
    }

    static func barkColor(for species: TreeSpecies) -> Color {
        switch species {
        case .birch: return Color(hex: 0xB0BEC5)
        case .oak: return Color(hex: 0x795548)
        case .willow: return Color(hex: 0x8D6E63)
        case .evergreen: return Color(hex: 0x6D4C41)
        case .ancientYew: return Color(hex: 0x4E342E)
        case .elderwood: return Color(hex: 0x5E4370)
        }
    }
}

/// Stacked gold coins for prices and balances.
struct CoinIcon: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xD9A406))
                .offset(y: size * 0.12)
            Circle()
                .fill(TimberlineTheme.gold)
            Circle()
                .stroke(Color(hex: 0xB8860B), lineWidth: 1.2)
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .frame(width: size, height: size)
    }
}
