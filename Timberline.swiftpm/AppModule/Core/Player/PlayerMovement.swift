import SwiftUI

/// Attaches a drag-to-move gesture to any view, driving the player's
/// velocity in `GameState.player`. Drag direction sets velocity; release
/// stops. No visual — this is pure input.
struct PlayerMovementModifier: ViewModifier {
    @EnvironmentObject private var game: GameState

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Velocity proportional to the drag offset from
                        // the initial touch point. The parent view
                        // provides the initial location via translation.
                        let dx = value.translation.width
                        let dy = value.translation.height
                        // Map screen pixels → world velocity.
                        // A drag of ~100px = full walk speed.
                        let scale: CGFloat = GameData.playerWalkSpeed / 80
                        game.player.velocity = CGPoint(
                            x: dx * scale,
                            y: dy * scale
                        )
                    }
                    .onEnded { _ in
                        game.player.velocity = .zero
                    }
            )
    }
}

extension View {
    func playerMovement() -> some View {
        modifier(PlayerMovementModifier())
    }
}
