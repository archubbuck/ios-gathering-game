import SwiftUI

/// Fixed-size circular minimap for the forest HUD's top-trailing corner.
/// Fixed north-up (no map rotation) — reads `game.worldTrees` filtered to
/// `GameData.minimapWorldRadius` around the player and draws
/// species-colored dots on a light-green ground, with a white heading
/// arrow at center that follows the last movement direction.
struct MinimapView: View {
    @EnvironmentObject private var game: GameState

    private let diameter: CGFloat = 104

    /// Last movement heading in world radians; defaults to "north" (up)
    /// until the player first moves. Screen-y and world-y both grow
    /// downward on the north-up map, so no sign flip is needed.
    @State private var headingRadians: Double = -.pi / 2

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let viewRadius = min(size.width, size.height) / 2
            let scale = viewRadius / GameData.minimapWorldRadius

            let backdrop = Path(ellipseIn: CGRect(origin: .zero, size: size))
            context.fill(backdrop, with: .color(SylvanTheme.groundLight.opacity(0.9)))

            for tree in game.worldTrees {
                let dx = tree.worldPosition.x - game.player.position.x
                let dy = tree.worldPosition.y - game.player.position.y
                let distance = (dx * dx + dy * dy).squareRoot()
                guard distance <= GameData.minimapWorldRadius else { continue }

                let dotCenter = CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
                let dotSize: CGFloat = 5
                let rect = CGRect(
                    x: dotCenter.x - dotSize / 2, y: dotCenter.y - dotSize / 2,
                    width: dotSize, height: dotSize
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(SylvanTheme.Scene3D.minimapDot(for: tree.species).opacity(0.85))
                )
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
        .overlay(Circle().stroke(SylvanTheme.hudBorder, lineWidth: 5))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .allowsHitTesting(false)
        .onChange(of: game.player.velocity) { velocity in
            guard hypot(velocity.x, velocity.y) > 0.01 else { return }
            headingRadians = Double(atan2(velocity.y, velocity.x))
        }
    }
}
