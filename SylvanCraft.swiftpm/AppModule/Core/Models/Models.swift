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

// MARK: - World & Player types (replaces region system)

/// Player movement direction for sprite flipping.
enum PlayerFacing: String, Codable {
    case left, right
}

/// Player animation state driving visual rendering.
enum PlayerAnimation: String, Codable {
    case idle, walking, chopping
}

/// The player character in world space.
struct PlayerState: Codable {
    var position: CGPoint  // world-space coordinates
    var facing: PlayerFacing = .right
    var animation: PlayerAnimation = .idle

    /// Point in time when the player entered proximity range of the
    /// current target tree. Nil when not near any tree.
    var dwellStart: Date? = nil
    /// Key of the tree the player is currently dwelling on.
    var dwellTargetKey: String? = nil
}

/// Uniquely identifies a world chunk.
struct ChunkCoord: Hashable, Codable {
    let x: Int
    let y: Int
}

/// A tree placed in the open world with a fixed world-space position.
struct WorldTreeState: Identifiable, Codable {
    /// Stable key: "\(chunkX):\(chunkY):\(indexInChunk)"
    let key: String
    let species: TreeSpecies
    var worldPosition: CGPoint
    var logsRemaining: Int
    var respawnUntil: Date?

    var id: String { key }

    var isDepleted: Bool {
        if let respawnUntil, respawnUntil > Date() { return true }
        return false
    }
}

/// A procedurally generated chunk containing trees and ground metadata.
struct Chunk: Codable {
    let coord: ChunkCoord
    var trees: [WorldTreeState]
}

struct AchievementContext {
    let stats: LifetimeStats
    let level: Int
    let ownedAxes: Set<AxeTier>
    /// Distance from origin the player has reached (in world units).
    let maxDistanceFromOrigin: Double
}

struct AchievementDef: Identifiable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let isUnlocked: (AchievementContext) -> Bool
}

// MARK: - Live state

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
    var schemaVersion: Int = 2
    var totalXP: Double
    var gold: Int
    var inventory: [TreeSpecies?]
    var bank: [ItemStack]
    var ownedAxes: Set<AxeTier>
    var equippedAxe: AxeTier
    /// Player's last-known world-space position.
    var playerPosition: CGPoint
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
            playerPosition: .zero,
            stats: LifetimeStats(),
            unlockedAchievements: []
        )
    }
}
