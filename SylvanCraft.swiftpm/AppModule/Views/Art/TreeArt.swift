import SwiftUI

/// Code-drawn vector trees, one silhouette per species, in a fixed
/// 100×130 design space. Callers scale with `.scaleEffect`.
struct TreeArt: View {
    let species: TreeSpecies
    var depleted: Bool = false

    var body: some View {
        ZStack {
            if depleted {
                StumpArt()
            } else {
                switch species {
                case .birch: BirchArt()
                case .oak: OakArt()
                case .willow: WillowArt()
                case .evergreen: EvergreenArt()
                case .ancientYew: AncientYewArt()
                case .elderwood: ElderwoodArt()
                }
            }
        }
        .frame(width: 100, height: 130)
    }
}

// MARK: - Shared pieces

private struct Trunk: View {
    var width: CGFloat = 14
    var height: CGFloat = 44
    var color: Color = SylvanTheme.bark

    var body: some View {
        TrunkShape()
            .fill(color)
            .overlay(TrunkShape().stroke(SylvanTheme.darkWood.opacity(0.6), lineWidth: 1.5))
            .frame(width: width, height: height)
    }
}

/// A gently flared trunk: narrow at the crown, wider at the roots.
private struct TrunkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let flare = rect.width * 0.35
        path.move(to: CGPoint(x: rect.minX + flare, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - flare, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - flare, y: rect.maxY * 0.75)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + flare, y: rect.minY),
            control: CGPoint(x: rect.minX + flare, y: rect.maxY * 0.75)
        )
        path.closeSubpath()
        return path
    }
}

private struct Canopy: View {
    var width: CGFloat
    var height: CGFloat
    var base: Color
    var highlight: Color

    var body: some View {
        ZStack {
            Ellipse()
                .fill(base)
            Ellipse()
                .fill(highlight)
                .frame(width: width * 0.6, height: height * 0.55)
                .offset(x: -width * 0.12, y: -height * 0.15)
        }
        .frame(width: width, height: height)
        .overlay(Ellipse().stroke(SylvanTheme.darkWood.opacity(0.4), lineWidth: 1.5))
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct StumpArt: View {
    var body: some View {
        VStack(spacing: 0) {
            Ellipse()
                .fill(SylvanTheme.parchmentEdge)
                .overlay(Ellipse().stroke(SylvanTheme.darkWood.opacity(0.6), lineWidth: 1.5))
                .frame(width: 26, height: 10)
                .zIndex(1)
            TrunkShape()
                .fill(SylvanTheme.bark)
                .overlay(TrunkShape().stroke(SylvanTheme.darkWood.opacity(0.6), lineWidth: 1.5))
                .frame(width: 24, height: 18)
                .offset(y: -4)
        }
        .offset(y: 48)
    }
}

// MARK: - Species

private struct BirchArt: View {
    var body: some View {
        ZStack {
            Trunk(width: 10, height: 52, color: Color(hex: 0xECEFF1))
                .overlay(
                    VStack(spacing: 9) {
                        ForEach(0..<4, id: \.self) { index in
                            Capsule()
                                .fill(SylvanTheme.darkWood.opacity(0.55))
                                .frame(width: 5, height: 2.5)
                                .offset(x: index.isMultiple(of: 2) ? -1.5 : 1.5)
                        }
                    }
                )
                .offset(y: 32)
            Canopy(
                width: 52, height: 48,
                base: SylvanTheme.canopyLight,
                highlight: Color(hex: 0x9CCC65)
            )
            .offset(y: -18)
        }
    }
}

private struct OakArt: View {
    var body: some View {
        ZStack {
            Trunk(width: 16, height: 46)
                .offset(y: 36)
            Canopy(width: 46, height: 42, base: SylvanTheme.canopyDark, highlight: SylvanTheme.forestGreen)
                .offset(x: -22, y: -2)
            Canopy(width: 46, height: 42, base: SylvanTheme.canopyDark, highlight: SylvanTheme.forestGreen)
                .offset(x: 22, y: -2)
            Canopy(
                width: 56, height: 50,
                base: SylvanTheme.forestGreen,
                highlight: SylvanTheme.canopyLight
            )
            .offset(y: -24)
        }
    }
}

private struct WillowArt: View {
    var body: some View {
        ZStack {
            Trunk(width: 13, height: 48)
                .offset(y: 34)
            Canopy(
                width: 68, height: 52,
                base: Color(hex: 0x7CB342),
                highlight: Color(hex: 0xAED581)
            )
            .offset(y: -14)
            // Drooping fronds
            WillowFronds()
                .stroke(Color(hex: 0x689F38), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 70, height: 56)
                .offset(y: 8)
        }
    }
}

private struct WillowFronds: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tops: [CGFloat] = [0.12, 0.32, 0.52, 0.72, 0.92]
        for fraction in tops {
            let x = rect.minX + rect.width * fraction
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: x + rect.width * 0.06, y: rect.maxY),
                control: CGPoint(x: x + rect.width * 0.1, y: rect.midY)
            )
        }
        return path
    }
}

private struct EvergreenArt: View {
    var body: some View {
        ZStack {
            Trunk(width: 12, height: 30)
                .offset(y: 44)
            ForEach(0..<3, id: \.self) { layer in
                TriangleShape()
                    .fill(layer.isMultiple(of: 2) ? SylvanTheme.canopyDark : SylvanTheme.forestGreen)
                    .overlay(TriangleShape().stroke(SylvanTheme.darkWood.opacity(0.4), lineWidth: 1.5))
                    .frame(
                        width: 64 - CGFloat(layer) * 14,
                        height: 42 - CGFloat(layer) * 6
                    )
                    .offset(y: 18 - CGFloat(layer) * 26)
            }
        }
    }
}

private struct AncientYewArt: View {
    var body: some View {
        ZStack {
            Trunk(width: 20, height: 42, color: Color(hex: 0x4E342E))
                .offset(y: 38)
            Canopy(
                width: 82, height: 58,
                base: Color(hex: 0x33691E),
                highlight: Color(hex: 0x558B2F)
            )
            .offset(y: -12)
        }
    }
}

private struct ElderwoodArt: View {
    var body: some View {
        ZStack {
            Trunk(width: 24, height: 48, color: Color(hex: 0x3E2723))
                .overlay(
                    // Twisted grain lines
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(Color(hex: 0x6D4C41).opacity(0.8))
                                .frame(width: 3, height: 14)
                                .rotationEffect(.degrees(index.isMultiple(of: 2) ? 12 : -12))
                        }
                    }
                )
                .offset(y: 34)
            Canopy(
                width: 78, height: 60,
                base: Color(hex: 0x4A3B78),
                highlight: Color(hex: 0x7E57C2)
            )
            .offset(y: -16)
            // Faint magical glints
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color(hex: 0xB39DDB))
                    .frame(width: 4, height: 4)
                    .offset(
                        x: [-20, 8, 24][index],
                        y: [-30, -6, -26][index]
                    )
            }
        }
    }
}
