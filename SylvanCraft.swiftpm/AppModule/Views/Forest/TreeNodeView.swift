import SwiftUI

/// One tree in the scrolling forest. Rendered at its world-space position
/// mapped through the camera. Shows dwell indicator, depletion progress,
/// respawn timer, and level-lock badge.
struct TreeNodeView: View {
    @EnvironmentObject private var game: GameState

    let tree: WorldTreeState
    let camera: Camera
    let screenSize: CGSize

    /// Is the player dwelling on this tree (in range but not yet chopping)?
    private var isDwelling: Bool {
        game.player.dwellTargetKey == tree.key && !game.isChopping
    }

    /// Is this the tree being actively chopped?
    private var isActive: Bool {
        game.activeChopTreeKey == tree.key
    }

    /// Is this tree locked behind a level requirement?
    private var isLocked: Bool {
        game.level < GameData.tree(for: tree.species).levelReq
    }

    private var depletionProgress: Double {
        let def = GameData.tree(for: tree.species)
        guard def.logsMax > 0 else { return 0 }
        return 1 - Double(tree.logsRemaining) / Double(def.logsMax)
    }

    /// Screen position derived from world position through camera.
    private var screenPosition: CGPoint {
        camera.screenPoint(for: tree.worldPosition, in: screenSize)
    }

    var body: some View {
        ZStack {
            // Ground contact shadow
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 64, height: 16)
                .offset(y: 58)

            TreeArt(species: tree.species, depleted: tree.isDepleted)
                .saturation(isLocked ? 0.25 : 1)
                .opacity(isLocked ? 0.6 : 1)
                .rotationEffect(.degrees(isActive ? 1.8 : 0), anchor: .bottom)
                .animation(
                    isActive
                        ? .easeInOut(duration: 0.3).repeatForever(autoreverses: true)
                        : .easeOut(duration: 0.2),
                    value: isActive
                )

            // Dwell indicator: pulsing ring when player is nearby.
            if isDwelling {
                let dwellElapsed: Double = {
                    guard let start = game.player.dwellStart else { return 0 }
                    return Date().timeIntervalSince(start)
                }()
                let dwellProgress = min(1, dwellElapsed / GameData.dwellDuration)
                Circle()
                    .stroke(SylvanTheme.gold, lineWidth: 2.5)
                    .frame(width: 72, height: 72)
                    .scaleEffect(0.7 + CGFloat(dwellProgress) * 0.25)
                    .opacity(0.9)
                    .animation(.easeInOut(duration: 0.3), value: dwellProgress)
                ProgressRing(progress: dwellProgress)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.black.opacity(0.2)))
                    .offset(y: -78)
            }

            // Respawn timer ring on depleted trees.
            if tree.isDepleted, let respawnUntil = tree.respawnUntil {
                TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
                    let total = GameData.tree(for: tree.species).respawnSeconds
                    let remaining = respawnUntil.timeIntervalSince(timeline.date)
                    ProgressRing(progress: 1 - max(0, min(1, remaining / total)))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.2)))
                        .offset(y: 26)
                }
            }

            // Depletion progress ring while chopping.
            if isActive {
                ProgressRing(progress: depletionProgress)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.25)))
                    .offset(y: -78)
            }

            // Level-lock badge.
            if isLocked {
                let level = GameData.tree(for: tree.species).levelReq
                HStack(spacing: 3) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(level)")
                        .font(.stat(11))
                }
                .foregroundStyle(SylvanTheme.textOnWood)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .offset(y: -70)
            }
        }
        .position(screenPosition)
        .zIndex(screenPosition.y / screenSize.height)
    }
}

