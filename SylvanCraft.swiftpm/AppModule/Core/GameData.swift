import Foundation
import CoreGraphics

/// Every balance number in the game. Tuning happens here, never in logic.
enum GameData {
    // MARK: Trees

    static let trees: [TreeSpecies: TreeDef] = [
        .birch: TreeDef(
            species: .birch, levelReq: 1, xpPerLog: 25, sellPrice: 3,
            successLow: 0.45, successHigh: 0.90,
            logsMin: 4, logsMax: 6, respawnSeconds: 6
        ),
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
        guard let def = trees[species] else {
            fatalError("Missing TreeDef for \(species)")
        }
        return def
    }

    // MARK: Axes

    static let axes: [AxeDef] = [
        AxeDef(tier: .bronze, levelReq: 1, cost: 0, power: 1.00),
        AxeDef(tier: .iron, levelReq: 1, cost: 100, power: 1.10),
        AxeDef(tier: .steel, levelReq: 6, cost: 500, power: 1.25),
        AxeDef(tier: .black, levelReq: 11, cost: 1_500, power: 1.35),
        AxeDef(tier: .mithril, levelReq: 21, cost: 5_000, power: 1.50),
        AxeDef(tier: .adamant, levelReq: 31, cost: 15_000, power: 1.75),
        AxeDef(tier: .rune, levelReq: 41, cost: 50_000, power: 2.00),
        AxeDef(tier: .dragon, levelReq: 61, cost: 250_000, power: 2.25),
    ]

    static func axe(for tier: AxeTier) -> AxeDef {
        guard let def = axes.first(where: { $0.tier == tier }) else {
            fatalError("Missing AxeDef for \(tier)")
        }
        return def
    }

    // MARK: Regions

    static let startingRegionID = "birchwood-glade"

    static let regions: [RegionDef] = [
        RegionDef(
            id: "birchwood-glade", name: "Birchwood Glade", levelReq: 1,
            slots: [
                TreeSlot(species: .birch, position: CGPoint(x: 0.28, y: 0.30), scale: 0.80),
                TreeSlot(species: .birch, position: CGPoint(x: 0.72, y: 0.34), scale: 0.85),
                TreeSlot(species: .birch, position: CGPoint(x: 0.30, y: 0.62), scale: 1.00),
                TreeSlot(species: .birch, position: CGPoint(x: 0.70, y: 0.68), scale: 1.05),
            ]
        ),
        RegionDef(
            id: "oak-vale", name: "Oak Vale", levelReq: 15,
            slots: [
                TreeSlot(species: .oak, position: CGPoint(x: 0.25, y: 0.32), scale: 0.82),
                TreeSlot(species: .oak, position: CGPoint(x: 0.68, y: 0.28), scale: 0.78),
                TreeSlot(species: .oak, position: CGPoint(x: 0.65, y: 0.64), scale: 1.05),
                TreeSlot(species: .birch, position: CGPoint(x: 0.28, y: 0.66), scale: 1.00),
            ]
        ),
        RegionDef(
            id: "willow-wetlands", name: "Willow Wetlands", levelReq: 30,
            slots: [
                TreeSlot(species: .willow, position: CGPoint(x: 0.30, y: 0.28), scale: 0.80),
                TreeSlot(species: .willow, position: CGPoint(x: 0.74, y: 0.36), scale: 0.88),
                TreeSlot(species: .willow, position: CGPoint(x: 0.32, y: 0.64), scale: 1.02),
                TreeSlot(species: .oak, position: CGPoint(x: 0.70, y: 0.68), scale: 1.05),
            ]
        ),
        RegionDef(
            id: "evergreen-reach", name: "Evergreen Reach", levelReq: 45,
            slots: [
                TreeSlot(species: .evergreen, position: CGPoint(x: 0.26, y: 0.30), scale: 0.80),
                TreeSlot(species: .evergreen, position: CGPoint(x: 0.70, y: 0.30), scale: 0.84),
                TreeSlot(species: .evergreen, position: CGPoint(x: 0.68, y: 0.66), scale: 1.05),
                TreeSlot(species: .willow, position: CGPoint(x: 0.30, y: 0.68), scale: 1.00),
            ]
        ),
        RegionDef(
            id: "yewmoor", name: "Yewmoor", levelReq: 60,
            slots: [
                TreeSlot(species: .ancientYew, position: CGPoint(x: 0.28, y: 0.32), scale: 0.82),
                TreeSlot(species: .ancientYew, position: CGPoint(x: 0.72, y: 0.28), scale: 0.78),
                TreeSlot(species: .ancientYew, position: CGPoint(x: 0.34, y: 0.66), scale: 1.05),
                TreeSlot(species: .evergreen, position: CGPoint(x: 0.72, y: 0.68), scale: 1.00),
            ]
        ),
        RegionDef(
            id: "elderwood-heart", name: "Elderwood Heart", levelReq: 75,
            slots: [
                TreeSlot(species: .elderwood, position: CGPoint(x: 0.30, y: 0.28), scale: 0.80),
                TreeSlot(species: .elderwood, position: CGPoint(x: 0.72, y: 0.34), scale: 0.86),
                TreeSlot(species: .elderwood, position: CGPoint(x: 0.32, y: 0.66), scale: 1.05),
                TreeSlot(species: .ancientYew, position: CGPoint(x: 0.70, y: 0.68), scale: 1.02),
            ]
        ),
    ]

    static func region(id: String) -> RegionDef {
        regions.first(where: { $0.id == id }) ?? regions[0]
    }

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
            detail: "Visit every region", symbol: "map",
            isUnlocked: { $0.stats.regionsVisited.count >= $0.totalRegionCount }
        ),
    ]

    // MARK: Tuning

    /// Seconds between chop attempts.
    static let tickInterval: TimeInterval = 0.6
    static let inventorySlots = 28
    static let eventLogCap = 50
}
