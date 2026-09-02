import Foundation
import CoreGraphics

/// Every balance number in the game. Tuning happens here, never in logic.
enum GameData {
    // MARK: Trees

    private static let birchTreeDef = TreeDef(
        species: .birch, levelReq: 1, xpPerLog: 25, sellPrice: 3,
        successLow: 0.45, successHigh: 0.90,
        logsMin: 4, logsMax: 6, respawnSeconds: 6
    )

    static let trees: [TreeSpecies: TreeDef] = [
        .birch: birchTreeDef,
        .oak: TreeDef(
            species: .oak, levelReq: 15, xpPerLog: 38, sellPrice: 8,
            successLow: 0.25, successHigh: 0.70,
            logsMin: 6, logsMax: 8, respawnSeconds: 9
        ),
        .willow: TreeDef(
            species: .willow, levelReq: 30, xpPerLog: 68, sellPrice: 15,
            successLow: 0.15, successHigh: 0.55,
            logsMin: 8, logsMax: 10, respawnSeconds: 12
        ),
        .evergreen: TreeDef(
            species: .evergreen, levelReq: 45, xpPerLog: 100, sellPrice: 45,
            successLow: 0.08, successHigh: 0.35,
            logsMin: 8, logsMax: 11, respawnSeconds: 14
        ),
        .ancientYew: TreeDef(
            species: .ancientYew, levelReq: 60, xpPerLog: 175, sellPrice: 120,
            successLow: 0.04, successHigh: 0.20,
            logsMin: 10, logsMax: 13, respawnSeconds: 20
        ),
        .elderwood: TreeDef(
            species: .elderwood, levelReq: 75, xpPerLog: 250, sellPrice: 320,
            successLow: 0.025, successHigh: 0.12,
            logsMin: 12, logsMax: 15, respawnSeconds: 30
        ),
    ]

    static func tree(for species: TreeSpecies) -> TreeDef {
        if let def = trees[species] {
            return def
        }
        assertionFailure("TreeDef not found for species: \(species). Check GameData.trees for missing entries.")
        // Fall back to the starter tree so gameplay can continue safely.
        return birchTreeDef
    }

    // MARK: Axes

    private static let defaultAxeDef = AxeDef(tier: .bronze, levelReq: 1, cost: 0, power: 1.00)

    static let axes: [AxeDef] = [
        defaultAxeDef,
        AxeDef(tier: .iron, levelReq: 1, cost: 100, power: 1.10),
        AxeDef(tier: .steel, levelReq: 6, cost: 500, power: 1.25),
        AxeDef(tier: .black, levelReq: 11, cost: 1_500, power: 1.35),
        AxeDef(tier: .mithril, levelReq: 21, cost: 5_000, power: 1.50),
        AxeDef(tier: .adamant, levelReq: 31, cost: 15_000, power: 1.75),
        AxeDef(tier: .rune, levelReq: 41, cost: 50_000, power: 2.00),
        AxeDef(tier: .dragon, levelReq: 61, cost: 250_000, power: 2.25),
    ]

    static func axe(for tier: AxeTier) -> AxeDef {
        if let def = axes.first(where: { $0.tier == tier }) {
            return def
        }
        assertionFailure("AxeDef not found for tier: \(tier). Check GameData.axes for missing entries.")
        // Fall back to the starter axe so gameplay can continue safely.
        return defaultAxeDef
    }

    // MARK: World generation

    /// World-space dimensions of one chunk (square, in points).
    static let chunkSize: CGFloat = 1200
    /// Number of chunks loaded around the player (radius). 3 → 7×7 grid.
    static let chunkLoadRadius = 3
    /// Trees per cluster in a chunk.
    static let treesPerClusterRange = 3...7
    /// Minimum separation between cluster centers (world units).
    static let clusterMinSeparation: CGFloat = 320
    /// Cluster centers per chunk.
    static let clustersPerChunk = 4

    /// Radius (world units) around the player within which trees get a
    /// visible sprite node. Deliberately smaller than the gameplay area
    /// implied by `chunkLoadRadius` — most loaded trees are never on-screen.
    static let treeRenderRadius: CGFloat = 1400
    /// Extra distance beyond `treeRenderRadius` before a tree node is torn
    /// down, so trees near the boundary don't spawn/despawn every diff.
    static let treeRenderHysteresis: CGFloat = 250

    /// World seed: deterministic generation. Change for alternate layouts.
    static var worldSeed: UInt64 { WorldSaveStore.current.worldSeed }

    /// Distance-from-origin bands where species unlock. Keyed by the
    /// minimum distance at which the species begins to appear.
    static let speciesSpawnBands: [(species: TreeSpecies, minDistance: CGFloat)] = [
        (.birch, 0),
        (.oak, 2000),
        (.willow, 4500),
        (.evergreen, 8000),
        (.ancientYew, 13000),
        (.elderwood, 20000),
    ]

    /// Eligible species for a given distance from origin.
    static func eligibleSpecies(atDistance distance: CGFloat) -> [TreeSpecies] {
        speciesSpawnBands.filter { distance >= $0.minDistance }.map(\.species)
    }

    // MARK: Potions

    /// Woodcutting level bonus granted while a potion boost is active.
    static let woodcuttingPotionLevelBoost = 6
    /// Duration of the woodcutting level boost.
    static let woodcuttingPotionDuration: TimeInterval = 300
    /// Radius within which a potion pickup is auto-collected.
    static let potionPickupRadius: CGFloat = 90
    /// Seconds before a collected pickup reappears at the same spot.
    static let potionRespawnSeconds: TimeInterval = 240
    /// Chance a given chunk spawns one potion pickup.
    static let potionSpawnChancePerChunk: Double = 0.35

    // MARK: Ads

    /// Length of the simulated "watch ad" countdown before the reward is
    /// granted. No real ad SDK is used — this is a placeholder timer.
    static let simulatedAdDuration: TimeInterval = 5
    /// Cooldown before "Watch Ad" is available again, counted from when
    /// the granted boost *ends* (not from when the ad was watched).
    static let adBoostCooldownDuration: TimeInterval = 600

    // MARK: Player

    /// Player walk speed in world units per second.
    static let playerWalkSpeed: CGFloat = 280
    /// Radius within which the player is "near" a tree (world units).
    static let proximityRadius: CGFloat = 110
    /// Seconds the player must remain near the same tree before chopping.
    static let dwellDuration: TimeInterval = 1.2
    /// Fraction into the chop-swing animation where the axe visually
    /// contacts the wood — the strike keyframe lands here, matching the
    /// instant `GameState.performChopTick()` actually resolves.
    static let chopStrikeFraction: Double = 0.55

    // MARK: Scene feel

    /// Visual-only tuning values. Gameplay timing above remains authoritative.
    static let chopSwingDuration: TimeInterval = 0.62
    static let chopImpactPause: TimeInterval = 0.055
    static let chopRecoilDistance: CGFloat = 2.5
    static let walkBobHeight: CGFloat = 1.8
    static let treeSwayAngle: CGFloat = 0.035
    static let treeFallDuration: TimeInterval = 0.34
    static let impactParticleCount = 8

    // MARK: Achievements

    static let achievements: [AchievementDef] = [
        AchievementDef(
            id: "first-chop", name: "First Chop",
            detail: "Chop your first log", symbol: "leaf",
            isUnlocked: { $0.stats.totalLogs >= 1 }
        ),
        AchievementDef(
            id: "getting-wood", name: "Getting Wood",
            detail: "Chop 100 logs", symbol: "tree",
            isUnlocked: { $0.stats.totalLogs >= 100 }
        ),
        AchievementDef(
            id: "lumberjack", name: "Lumberjack",
            detail: "Chop 1,000 logs", symbol: "hammer",
            isUnlocked: { $0.stats.totalLogs >= 1_000 }
        ),
        AchievementDef(
            id: "forest-legend", name: "Forest Legend",
            detail: "Chop 10,000 logs", symbol: "crown",
            isUnlocked: { $0.stats.totalLogs >= 10_000 }
        ),
        AchievementDef(
            id: "oak-devotee", name: "Oak Devotee",
            detail: "Chop 1,000 Oak logs", symbol: "circle.hexagongrid",
            isUnlocked: { ($0.stats.logsBySpecies[.oak] ?? 0) >= 1_000 }
        ),
        AchievementDef(
            id: "willow-whisperer", name: "Willow Whisperer",
            detail: "Chop 1,000 Willow logs", symbol: "wind",
            isUnlocked: { ($0.stats.logsBySpecies[.willow] ?? 0) >= 1_000 }
        ),
        AchievementDef(
            id: "arborist", name: "Arborist",
            detail: "Chop every species at least once", symbol: "books.vertical",
            isUnlocked: { ctx in
                TreeSpecies.allCases.allSatisfy { (ctx.stats.logsBySpecies[$0] ?? 0) > 0 }
            }
        ),
        AchievementDef(
            id: "halfway-there", name: "Halfway There",
            detail: "Reach level 50", symbol: "figure.climbing",
            isUnlocked: { $0.level >= 50 }
        ),
        AchievementDef(
            id: "master-woodcutter", name: "Master Woodcutter",
            detail: "Reach level 99", symbol: "star.circle",
            isUnlocked: { $0.level >= 99 }
        ),
        AchievementDef(
            id: "first-sale", name: "First Sale",
            detail: "Earn your first gold", symbol: "dollarsign.circle",
            isUnlocked: { $0.stats.lifetimeGold >= 1 }
        ),
        AchievementDef(
            id: "full-pouch", name: "Full Pouch",
            detail: "Earn 10,000 gp lifetime", symbol: "bag",
            isUnlocked: { $0.stats.lifetimeGold >= 10_000 }
        ),
        AchievementDef(
            id: "timber-tycoon", name: "Timber Tycoon",
            detail: "Earn 250,000 gp lifetime", symbol: "building.columns",
            isUnlocked: { $0.stats.lifetimeGold >= 250_000 }
        ),
        AchievementDef(
            id: "fully-equipped", name: "Fully Equipped",
            detail: "Own the Dragon axe", symbol: "flame",
            isUnlocked: { $0.ownedAxes.contains(.dragon) }
        ),
        AchievementDef(
            id: "wanderer", name: "Wanderer",
            detail: "Walk 15,000 world units from origin", symbol: "map",
            isUnlocked: { $0.maxDistanceFromOrigin >= 15_000 }
        ),
        AchievementDef(
            id: "explorer", name: "Explorer",
            detail: "Walk 30,000 world units from origin", symbol: "globe",
            isUnlocked: { $0.maxDistanceFromOrigin >= 30_000 }
        ),
    ]

    // MARK: Minimap

    /// World-space radius shown on the minimap, centered on the player.
    static let minimapWorldRadius: CGFloat = 900

    // MARK: Tuning

    /// Seconds between chop attempts.
    static let tickInterval: TimeInterval = 0.6
    static let inventorySlots = 28
    static let eventLogCap = 50
    /// Seconds between wall-clock-timed autosaves in the per-frame update
    /// loop (covers plain movement, which doesn't go through any of the
    /// action methods that call `scheduleSave()` directly).
    static let autoSaveInterval: TimeInterval = 15
}