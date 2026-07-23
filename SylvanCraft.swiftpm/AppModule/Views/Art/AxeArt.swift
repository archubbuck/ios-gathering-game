import SwiftUI

/// Per-tier axe icon: crescent blade over a diagonal wooden handle, metal
/// colors keyed by tier.
struct AxeArt: View {
    let tier: AxeTier

    var body: some View {
        let metal = AxeArt.metalColors(for: tier)
        ZStack {
            Capsule()
                .fill(SylvanTheme.barkLight)
                .overlay(Capsule().stroke(SylvanTheme.darkWood.opacity(0.5), lineWidth: 1))
                .frame(width: 7, height: 46)
                .rotationEffect(.degrees(24))
                .offset(x: 3, y: 6)

            AxeHeadShape()
                .fill(
                    LinearGradient(
                        colors: [metal.light, metal.dark],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(AxeHeadShape().stroke(SylvanTheme.darkWood.opacity(0.55), lineWidth: 1.2))
                .frame(width: 28, height: 24)
                .offset(x: -8, y: -14)
        }
        .frame(width: 48, height: 58)
    }

    static func metalColors(for tier: AxeTier) -> (light: Color, dark: Color) {
        switch tier {
        case .bronze: return (Color(hex: 0xC98F5A), Color(hex: 0x8D5B33))
        case .iron: return (Color(hex: 0xB0AaA2), Color(hex: 0x7C7873))
        case .steel: return (Color(hex: 0xDDE4E8), Color(hex: 0x90A4AE))
        case .black: return (Color(hex: 0x546E7A), Color(hex: 0x263238))
        case .mithril: return (Color(hex: 0x7986CB), Color(hex: 0x3949AB))
        case .adamant: return (Color(hex: 0x81C784), Color(hex: 0x2E7D32))
        case .rune: return (Color(hex: 0x4DD0E1), Color(hex: 0x00838F))
        case .dragon: return (Color(hex: 0xEF5350), Color(hex: 0xB71C1C))
        }
    }
}

/// Crescent axe blade opening toward the handle.
struct AxeHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = CGPoint(x: rect.maxX * 0.9, y: rect.minY + rect.height * 0.08)
        let bottom = CGPoint(x: rect.maxX * 0.9, y: rect.maxY - rect.height * 0.08)
        path.move(to: top)
        path.addQuadCurve(
            to: bottom,
            control: CGPoint(x: rect.minX - rect.width * 0.35, y: rect.midY)
        )
        path.addQuadCurve(
            to: top,
            control: CGPoint(x: rect.midX * 0.9, y: rect.midY)
        )
        path.closeSubpath()
        return path
    }
}
