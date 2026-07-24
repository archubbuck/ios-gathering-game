import SwiftUI

/// Fixed-size circular minimap for the forest HUD's top-trailing corner.
/// Fixed north-up (no rotation, avoids an unverifiable correctness question
/// without a device to test on) — reads `game.worldTrees` filtered to
/// `GameData.minimapWorldRadius` around the player and draws
/// species-colored dots plus a center player marker.
struct MinimapView: View {
    @EnvironmentObject private var game: GameState

    private let diameter: CGFloat = 104

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let viewRadius = min(size.width, size.height) / 2
            let scale = viewRadius / GameData.minimapWorldRadius

            let backdrop = Path(ellipseIn: CGRect(origin: .zero, size: size))
            context.fill(backdrop, with: .color(SylvanTheme.woodPanelBottom.opacity(0.85)))

            for tree in game.worldTrees {
                let dx = tree.worldPosition.x - game.player.position.x
                let dy = tree.worldPosition.y - game.player.position.y
                let distance = (dx * dx + dy * dy).squareRoot()
                guard distance <= GameData.minimapWorldRadius else { continue }

                let dotCenter = CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
                let dotSize: CGFloat = 3.5
                let rect = CGRect(
                    x: dotCenter.x - dotSize / 2, y: dotCenter.y - dotSize / 2,
                    width: dotSize, height: dotSize
                )
                context.fill(Path(ellipseIn: rect), with: .color(Self.dotColor(for: tree.species)))
            }

            let markerSize: CGFloat = 7
            let markerRect = CGRect(
                x: center.x - markerSize / 2, y: center.y - markerSize / 2,
                width: markerSize, height: markerSize
            )
            context.fill(Path(ellipseIn: markerRect), with: .color(SylvanTheme.gold))
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().stroke(SylvanTheme.barkLight, lineWidth: 2))
        .shadow(color: .black.opacity(0.4), radius: 4)
        .allowsHitTesting(false)
    }

    /// Mirrors `Views/Art/TreeArt.swift`'s per-species canopy colors so dots
    /// stay recognizable alongside the 3D scene's tree palette.
    private static func dotColor(for species: TreeSpecies) -> Color {
        switch species {
        case .birch: return SylvanTheme.canopyLight
        case .oak: return SylvanTheme.forestGreen
        case .willow: return Color(hex: 0x7CB342)
        case .evergreen: return SylvanTheme.canopyDark
        case .ancientYew: return Color(hex: 0x33691E)
        case .elderwood: return Color(hex: 0x4A3B78)
        }
    }
}
