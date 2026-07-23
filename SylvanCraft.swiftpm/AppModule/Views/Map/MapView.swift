import SwiftUI

/// Tab 3: parchment world map with level-locked region nodes connected by
/// a dashed trail, and a pulsing "You are here" marker.
struct MapView: View {
    @EnvironmentObject private var game: GameState

    /// Hand-placed node positions (unit coords), bottom → top in
    /// progression order, winding left/right like a trail.
    private static let nodePositions: [CGPoint] = [
        CGPoint(x: 0.30, y: 0.87),
        CGPoint(x: 0.68, y: 0.73),
        CGPoint(x: 0.32, y: 0.59),
        CGPoint(x: 0.66, y: 0.45),
        CGPoint(x: 0.34, y: 0.31),
        CGPoint(x: 0.64, y: 0.15),
    ]

    var body: some View {
        ZStack {
            SylvanTheme.parchment.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    ParchmentTexture()
                    trail(in: geo.size)

                    ForEach(Array(GameData.regions.enumerated()), id: \.element.id) { index, region in
                        let point = Self.nodePositions[index]
                        RegionNodeView(
                            region: region,
                            isCurrent: game.currentRegionID == region.id,
                            isUnlocked: game.level >= region.levelReq,
                            onTap: { game.travel(to: region.id) }
                        )
                        .position(
                            x: point.x * geo.size.width,
                            y: point.y * geo.size.height
                        )
                    }

                    Text("World Map")
                        .font(.display(26))
                        .foregroundStyle(SylvanTheme.textOnParchment)
                        .position(x: geo.size.width / 2, y: 28)
                }
            }
            .padding(12)
        }
    }

    private func trail(in size: CGSize) -> some View {
        Path { path in
            let points = Self.nodePositions.map {
                CGPoint(x: $0.x * size.width, y: $0.y * size.height)
            }
            guard let first = points.first else { return }
            path.move(to: first)
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let control = CGPoint(
                    x: (previous.x + current.x) / 2,
                    y: previous.y - (previous.y - current.y) * 0.15
                )
                path.addQuadCurve(to: current, control: control)
            }
        }
        .stroke(
            SylvanTheme.bark.opacity(0.55),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 9])
        )
    }
}

/// Aged-parchment speckle and edge shading.
private struct ParchmentTexture: View {
    var body: some View {
        Canvas { context, size in
            var generator = SeededRandom(seed: 9)
            for _ in 0..<140 {
                let x = generator.next() * size.width
                let y = generator.next() * size.height
                let radius = 0.8 + generator.next() * 1.8
                let dot = Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius))
                context.fill(dot, with: .color(SylvanTheme.parchmentEdge.opacity(0.25 + generator.next() * 0.3)))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(SylvanTheme.parchmentEdge, lineWidth: 3)
                .padding(2)
        )
    }
}

/// Deterministic pseudo-random stream so the texture never shimmers
/// between renders.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E3779B97F4A7C15 &+ 1
    }

    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
}

private struct RegionNodeView: View {
    let region: RegionDef
    let isCurrent: Bool
    let isUnlocked: Bool
    let onTap: () -> Void

    @State private var pulsing = false

    private var primarySpecies: TreeSpecies {
        region.slots.first?.species ?? .birch
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                if isCurrent {
                    Circle()
                        .stroke(SylvanTheme.gold, lineWidth: 3)
                        .frame(width: 66, height: 66)
                        .scaleEffect(pulsing ? 1.12 : 0.96)
                        .opacity(pulsing ? 0.45 : 0.9)
                }

                Circle()
                    .fill(isUnlocked ? SylvanTheme.forestGreen : SylvanTheme.locked)
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(SylvanTheme.darkWood.opacity(0.5), lineWidth: 2))

                if isUnlocked {
                    TreeArt(species: primarySpecies)
                        .scaleEffect(0.32)
                        .frame(width: 44, height: 44)
                        .offset(y: -2)
                } else {
                    VStack(spacing: 1) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Lv \(region.levelReq)")
                            .font(.stat(10))
                    }
                    .foregroundStyle(.white)
                }
            }

            Text(region.name)
                .font(.stat(12))
                .foregroundStyle(
                    isUnlocked ? SylvanTheme.textOnParchment : SylvanTheme.textOnParchmentSecondary
                )
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(SylvanTheme.parchmentLight.opacity(0.9)))

            if isCurrent {
                Text("You are here")
                    .font(.stat(10))
                    .foregroundStyle(SylvanTheme.gold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(SylvanTheme.darkWood))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            guard isCurrent else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .onChange(of: isCurrent) { current in
            if current {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            } else {
                pulsing = false
            }
        }
    }
}
