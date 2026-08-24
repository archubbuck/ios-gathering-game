import SwiftUI

/// Circular minimap for the forest HUD's top-trailing corner. Tap to
/// toggle between a compact and an expanded size. Fixed north-up (no map
/// rotation) — reads `game.worldTrees` filtered to
/// `GameData.minimapWorldRadius` around the player and draws
/// species-colored dots on a light-green ground, cluster indicator rings
/// behind them, and a white heading arrow at center that follows the last
/// movement direction.
struct MinimapView: View {
    @EnvironmentObject private var game: GameState

    /// Derived from the device's available canvas size (see `DeviceScale`)
    /// so the minimap stays proportionate from iPhone SE to iPad.
    var scale: CGFloat = 1

    @State private var isExpanded = false

    private var diameter: CGFloat {
        (isExpanded ? 220 : 104) * scale
    }

    /// Last movement heading in world radians; defaults to "north" (up)
    /// until the player first moves. Screen-y and world-y both grow
    /// downward on the north-up map, so no sign flip is needed.
    @State private var headingRadians: Double = -.pi / 2

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let viewRadius = min(size.width, size.height) / 2
            let mapScale = viewRadius / GameData.minimapWorldRadius

            let backdrop = Path(ellipseIn: CGRect(origin: .zero, size: size))
            context.fill(backdrop, with: .color(TimberlineTheme.groundLight.opacity(0.9)))

            let visibleTrees = game.worldTrees.filter { tree in
                let dx = tree.worldPosition.x - game.player.position.x
                let dy = tree.worldPosition.y - game.player.position.y
                return (dx * dx + dy * dy).squareRoot() <= GameData.minimapWorldRadius
            }

            // Cluster indicator rings, drawn first so individual tree dots
            // stay legible on top of them.
            let clusters = Dictionary(grouping: visibleTrees, by: \.clusterID)
            for (_, trees) in clusters {
                guard let species = trees.first?.species else { continue }
                let count = CGFloat(trees.count)
                let avgX = trees.reduce(0) { $0 + $1.worldPosition.x } / count
                let avgY = trees.reduce(0) { $0 + $1.worldPosition.y } / count
                let dx = avgX - game.player.position.x
                let dy = avgY - game.player.position.y
                let ringCenter = CGPoint(x: center.x + dx * mapScale, y: center.y + dy * mapScale)
                let ringDiameter = min(24, 12 + count)
                let ringRect = CGRect(
                    x: ringCenter.x - ringDiameter / 2, y: ringCenter.y - ringDiameter / 2,
                    width: ringDiameter, height: ringDiameter
                )
                context.stroke(
                    Path(ellipseIn: ringRect),
                    with: .color(TimberlineTheme.SceneArt.minimapDot(for: species).opacity(0.55)),
                    lineWidth: 2
                )
            }

            for tree in visibleTrees {
                let dx = tree.worldPosition.x - game.player.position.x
                let dy = tree.worldPosition.y - game.player.position.y
                let dotCenter = CGPoint(x: center.x + dx * mapScale, y: center.y + dy * mapScale)
                let dotSize: CGFloat = 5
                let rect = CGRect(
                    x: dotCenter.x - dotSize / 2, y: dotCenter.y - dotSize / 2,
                    width: dotSize, height: dotSize
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(TimberlineTheme.SceneArt.minimapDot(for: tree.species).opacity(0.85))
                )
            }

            for pickup in game.worldPickups where !pickup.isCollected {
                let dx = pickup.worldPosition.x - game.player.position.x
                let dy = pickup.worldPosition.y - game.player.position.y
                let distance = (dx * dx + dy * dy).squareRoot()
                guard distance <= GameData.minimapWorldRadius else { continue }

                let dotCenter = CGPoint(x: center.x + dx * mapScale, y: center.y + dy * mapScale)
                let dotSize: CGFloat = 7
                let rect = CGRect(
                    x: dotCenter.x - dotSize / 2, y: dotCenter.y - dotSize / 2,
                    width: dotSize, height: dotSize
                )
                // Diamond shape distinguishes pickups from round tree dots.
                var diamond = Path()
                diamond.move(to: CGPoint(x: rect.midX, y: rect.minY))
                diamond.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                diamond.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                diamond.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
                diamond.closeSubpath()
                context.fill(diamond, with: .color(TimberlineTheme.SceneArt.potionMinimapDot))
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(
            Image(systemName: "location.north.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
                .rotationEffect(Angle(radians: headingRadians + .pi / 2))
        )
        .overlay(Circle().stroke(TimberlineTheme.hudBorder, lineWidth: 5))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .contentShape(Circle())
        .accessibilityLabel("Minimap")
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
        .onChange(of: game.player.velocity) { velocity in
            guard hypot(velocity.x, velocity.y) > 0.01 else { return }
            headingRadians = Double(atan2(velocity.y, velocity.x))
        }
    }
}
