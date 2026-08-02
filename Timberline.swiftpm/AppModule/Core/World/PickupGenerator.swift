import Foundation
import CoreGraphics

/// Deterministic per-chunk placement of Woodcutting Potion pickups,
/// mirroring `WorldGenerator`/`DecorationGenerator`'s seeding pattern but
/// salted separately so pickup spawns don't correlate with tree clusters
/// or decorations. Same seed + coord → same layout.
enum PickupGenerator {
    /// At most one potion pickup per chunk, placed with
    /// `GameData.potionSpawnChancePerChunk` probability.
    static func generate(for coord: ChunkCoord) -> [PotionPickupState] {
        var rng = SeededRandom(seed: hash(coord))
        guard rng.nextCGFloat() < GameData.potionSpawnChancePerChunk else { return [] }

        let originX = CGFloat(coord.x) * GameData.chunkSize
        let originY = CGFloat(coord.y) * GameData.chunkSize
        let margin: CGFloat = 60
        let position = CGPoint(
            x: originX + margin + rng.nextCGFloat() * (GameData.chunkSize - margin * 2),
            y: originY + margin + rng.nextCGFloat() * (GameData.chunkSize - margin * 2)
        )

        let key = "potion:\(coord.x):\(coord.y):0"
        return [PotionPickupState(key: key, worldPosition: position, respawnUntil: nil)]
    }

    /// `WorldGenerator.hash`/`DecorationGenerator.hash` with a distinct salt.
    private static func hash(_ coord: ChunkCoord) -> UInt64 {
        var h = GameData.worldSeed ^ 0x907_1104
        h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(coord.x))
        h = h &* 0x9E3779B97F4A7C15 &+ UInt64(bitPattern: Int64(coord.y))
        return h
    }
}
