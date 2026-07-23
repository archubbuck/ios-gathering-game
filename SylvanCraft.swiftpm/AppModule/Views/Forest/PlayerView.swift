import SwiftUI

/// The player character rendered on the isometric forest scene.
/// A small humanoid silhouette with an axe that swings when chopping.
struct PlayerView: View {
    @EnvironmentObject private var game: GameState

    /// Degrees of axe rotation during chop swing.
    @State private var axeSwingAngle: Double = -30

    var body: some View {
        let facing = game.player.facing
        let anim = game.player.animation

        ZStack {
            // Ground shadow
            Ellipse()
                .fill(Color.black.opacity(0.22))
                .frame(width: 44, height: 12)
                .offset(y: 42)

            // Body
            VStack(spacing: 0) {
                // Head
                Circle()
                    .fill(SkinTone.base)
                    .overlay(Circle().stroke(SkinTone.outline, lineWidth: 1.5))
                    .frame(width: 18, height: 18)

                // Torso
                RoundedRectangle(cornerRadius: 4)
                    .fill(SylvanTheme.barkLight)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(SylvanTheme.darkWood.opacity(0.6), lineWidth: 1.2))
                    .frame(width: 20, height: 22)
            }

            // Legs
            HStack(spacing: 4) {
                Capsule()
                    .fill(SylvanTheme.darkWood)
                    .frame(width: 8, height: anim == .walking ? 18 : 20)
                    .offset(y: anim == .walking ? 2 : 0)
                Capsule()
                    .fill(SylvanTheme.darkWood)
                    .frame(width: 8, height: anim == .walking ? 22 : 20)
                    .offset(y: anim == .walking ? -2 : 0)
            }
            .offset(y: 36)

            // Axe (held to one side, facing determines which)
            AxeArt(tier: game.equippedAxe)
                .scaleEffect(0.55)
                .scaleEffect(x: facing == .left ? -1 : 1, y: 1)
                .rotationEffect(.degrees(axeSwingAngle), anchor: .bottom)
                .offset(
                    x: facing == .right ? 20 : -20,
                    y: anim == .chopping ? -8 : 4
                )
        }
        .scaleEffect(x: facing == .left ? -1 : 1, y: 1)
        .offset(y: anim == .walking ? bobOffset : 0)
        .animation(.easeInOut(duration: 0.22).repeatForever(autoreverses: true),
                   value: anim == .walking)
        .onChange(of: anim) { newAnim in
            if newAnim == .chopping {
                startAxeSwing()
            }
        }
    }

    /// Sine-wave bob while walking.
    private var bobOffset: CGFloat {
        sin(CACurrentMediaTime() * 8) * 2
    }

    /// Repeating axe swing: wind up → chop down → pause → repeat.
    private func startAxeSwing() {
        func swing() {
            guard game.player.animation == .chopping else { return }
            withAnimation(.easeIn(duration: 0.15)) {
                axeSwingAngle = -90
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                guard game.player.animation == .chopping else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    axeSwingAngle = 20
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    guard game.player.animation == .chopping else { return }
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        axeSwingAngle = -30
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        swing()
                    }
                }
            }
        }
        swing()
    }
}

/// Simplified human skin tone palette.
private enum SkinTone {
    static let base = Color(hex: 0xFFCC99)
    static let outline = Color(hex: 0xD4A06A)
}
