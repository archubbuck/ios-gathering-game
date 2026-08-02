import CoreGraphics
import Foundation

/// A purely visual scene prop — boulders, dirt patches, pebbles.
/// Decorations are derived deterministically from the chunk coordinate and
/// are NEVER stored in `GameState` or saves: despawning and regenerating a
/// chunk always reproduces the identical layout.
struct DecorationInstance {
    enum Kind {
        case rock(radius: CGFloat)
        case dirtPatch(radius: CGFloat, light: Bool)
        case pebble(radius: CGFloat)
    }

    let kind: Kind
    let worldPosition: CGPoint
    /// Yaw applied to the node, in radians.
    let rotation: CGFloat
    /// Per-instance geometry seed (also used to pick a cached variant).
    let seed: UInt64
}

/// Deterministic per-chunk decoration layout, mirroring
/// `WorldGenerator.generateChunk`'s seeding pattern but salted so
/// decoration placement doesn't correlate with tree placement.
enum DecorationGenerator {
    static func decorations(for coord: ChunkCoord) -> [DecorationInstance] {
        var rng = SeededRandom(seed: hash(coord))
        let originX = CGFloat(coord.x) * GameData.chunkSize
        let originY = CGFloat(coord.y) * GameData.chunkSize
        let margin: CGFloat = 30

        func point() -> CGPoint {
            CGPoint(
                x: originX + margin + rng.nextCGFloat() * (GameData.chunkSize - margin * 2),
                y: originY + margin + rng.nextCGFloat() * (GameData.chunkSize - margin * 2)
            )
        }

        var instances: [DecorationInstance] = []

        // 2-3 irregular dirt/sand patches. Occasional overlap with trees
        // is acceptable — patches are flat and sit under everything.
        let patchCount = Int(randomIn: 2...3, using: &rng)
        for _ in 0..<patchCount {
            instances.append(DecorationInstance(
                kind: .dirtPatch(
                    radius: 40 + rng.nextCGFloat() * 50,
                    light: rng.nextCGFloat() < 0.5
                ),
                worldPosition: point(),
                rotation: rng.nextCGFloat() * .pi * 2,
                seed: rng.next()
            ))
        }

        // 1-2 boulder clusters of 2-4 rocks each.
        let clusterCount = Int(randomIn: 1...2, using: &rng)
        for _ in 0..<clusterCount {
            let center = point()
            let rockCount = Int(randomIn: 2...4, using: &rng)
            for _ in 0..<rockCount {
                let angle = rng.nextCGFloat() * .pi * 2
                let distance = rng.nextCGFloat() * 40
                instances.append(DecorationInstance(
                    kind: .rock(radius: 8 + rng.nextCGFloat() * 14),
                    worldPosition: CGPoint(
                        x: center.x + cos(angle) * distance,
                        y: center.y + sin(angle) * distance
                    ),
                    rotation: rng.nextCGFloat() * .pi * 2,
                    seed: rng.next()
                ))
            }
        }

        // ~30% chance of a small tan pebble triple.
        if rng.nextCGFloat() < 0.3 {
            let center = point()
            for _ in 0..<3 {
                instances.append(DecorationInstance(
                    kind: .pebble(radius: 3 + rng.nextCGFloat() * 2),
                    worldPosition: CGPoint(
                        x: center.x + (rng.nextCGFloat() * 2 - 1) * 14,
                        y: center.y + (rng.nextCGFloat() * 2 - 1) * 14
                    ),
                    rotation: rng.nextCGFloat() * .pi * 2,
                    seed: rng.next()
                ))
            }
        }

        return instances
    }

    /// `WorldGenerator.hash` with a salt, so rocks don't shadow tree
    /// clusters chunk after chunk.
    private static func hash(_ coord: ChunkCoord) -> UInt64 {
        var h = GameData.worldSeed ^ 0xDEC0
        h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(coord.x))
        h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(coord.y))
        return h
    }
}
