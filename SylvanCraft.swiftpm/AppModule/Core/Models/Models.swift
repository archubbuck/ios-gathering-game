import Foundation
import CoreGraphics

// MARK: - Species & tiers

enum TreeSpecies: String, Codable, CaseIterable, Identifiable {
    case birch, oak, willow, evergreen, ancientYew, elderwood

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .birch: return "Birch"
        case .oak: return "Oak"
        case .willow: return "Willow"
        case .evergreen: return "Evergreen"
        case .ancientYew: return "Ancient Yew"
        case .elderwood: return "Elderwood"
        }
    }

    var logName: String { "\(displayName) log" }
}

enum AxeTier: String, Codable, CaseIterable, Identifiable {
    case bronze, iron, steel, black, mithril, adamant, rune, dragon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .iron: return "Iron"
        case .steel: return "Steel"
        case .black: return "Black"
        case .mithril: return "Mithril"
        case .adamant: return "Adamant"
        case .rune: return "Rune"
        case .dragon: return "Dragon"
        }
    }
}

// MARK: - Static definitions (balance data lives in GameData.swift)

struct TreeDef {
    let species: TreeSpecies
    let levelReq: Int
    let xpPerLog: Double
    let sellPrice: Int
    /// Per-tick success chance at level 1 with a 1.0-power axe.
    let successLow: Double
    /// Per-tick success chance at level 99 with a 1.0-power axe.
    let successHigh: Double
    let logsMin: Int
    let logsMax: Int
    let respawnSeconds: TimeInterval
}

struct AxeDef {
    let tier: AxeTier
    let levelReq: Int
    /// Purchase price in gp. Bronze is the free starter axe.
    let cost: Int
    /// Multiplier on the tree's base success chance.
    let power: Double
}

/// A fixed tree position within a region, in unit coordinates (0–1)
/// mapped onto the isometric ground plane. Smaller scale = farther away.
struct TreeSlot {
    let species: TreeSpecies
    let position: CGPoint
    let scale: CGFloat
}

struct RegionDef: Identifiable {
    let id: String
    let name: String
    let levelReq: Int
    let slots: [TreeSlot]
}

struct AchievementContext {
    let stats: LifetimeStats
    let level: Int
    let ownedAxes: Set<AxeTier>
    let totalRegionCount: Int
}

struct AchievementDef: Identifiable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let isUnlocked: (AchievementContext) -> Bool
}

// MARK: - Live state

/// Runtime state of one tree slot in the current region. Identified by
/// slot index; regenerated whenever the player travels.
struct TreeState: Identifiable {
    let slotIndex: Int
    let species: TreeSpecies
    var logsRemaining: Int
    var respawnUntil: Date?

    var id: Int { slotIndex }

    var isDepleted: Bool {
        if let respawnUntil, respawnUntil > Date() { return true }
        return false
    }
}

/// A stack of logs in the bank. Inventory logs do not stack (one log per
/// slot, OSRS-style); the bank stacks freely.
struct ItemStack: Codable, Equatable, Identifiable {
    var species: TreeSpecies
    var count: Int

    var id: String { species.rawValue }
}

struct LifetimeStats: Codable, Equatable {
    var logsBySpecies: [TreeSpecies: Int] = [:]
    var totalLogs: Int = 0
    var lifetimeGold: Int = 0
    var regionsVisited: Set<String> = []
}

struct EventLogEntry: Identifiable, Equatable {
    enum Kind {
        case info, chop, warning, levelUp, achievement
    }

    let id = UUID()
    let kind: Kind
    let text: String
}

/// Drives the floating "+25 XP" overlay; a fresh id per drop restarts the
/// animation.
struct XPDrop: Identifiable, Equatable {
    let id = UUID()
    let amount: Double
}

// MARK: - Persistence snapshot

struct PlayerSave: Codable {
    var schemaVersion: Int = 1
    var totalXP: Double
    var gold: Int
    var inventory: [TreeSpecies?]
    var bank: [ItemStack]
    var ownedAxes: Set<AxeTier>
    var equippedAxe: AxeTier
    var currentRegionID: String
    var stats: LifetimeStats
    var unlockedAchievements: Set<String>

    static var newGame: PlayerSave {
        PlayerSave(
            totalXP: 0,
            gold: 25,
            inventory: Array(repeating: nil, count: 28),
            bank: [],
            ownedAxes: [.bronze],
            equippedAxe: .bronze,
            currentRegionID: GameData.startingRegionID,
            stats: LifetimeStats(regionsVisited: [GameData.startingRegionID]),
            unlockedAchievements: []
        )
    }
}
