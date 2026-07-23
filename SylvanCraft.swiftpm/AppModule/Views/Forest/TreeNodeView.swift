import SwiftUI

/// One tappable tree in the forest scene.
struct TreeNodeView: View {
    let tree: TreeState
    let slot: TreeSlot
    let isActive: Bool
    let isLocked: Bool
    let onTap: () -> Void

    private var depletionProgress: Double {
        let def = GameData.tree(for: tree.species)
        guard def.logsMax > 0 else { return 0 }
        return 1 - Double(tree.logsRemaining) / Double(def.logsMax)
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

            if isActive {
                ProgressRing(progress: depletionProgress)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.25)))
                    .offset(y: -78)
            }

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
        .scaleEffect(slot.scale)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
