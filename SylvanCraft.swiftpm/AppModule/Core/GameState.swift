import SwiftUI

/// Single source of truth for all game progress. Injected once at the app
/// root; every screen reads and mutates through it.
@MainActor
final class GameState: ObservableObject {
    @Published private(set) var totalXP: Double
    @Published private(set) var gold: Int
    @Published private(set) var inventory: [TreeSpecies?]
    @Published private(set) var bank: [ItemStack]
    @Published private(set) var ownedAxes: Set<AxeTier>
    @Published private(set) var equippedAxe: AxeTier
    @Published private(set) var currentRegionID: String
    @Published private(set) var trees: [TreeState]
    @Published private(set) var stats: LifetimeStats
    @Published private(set) var unlockedAchievements: Set<String>
    @Published private(set) var eventLog: [EventLogEntry] = []
    @Published private(set) var activeChopTreeID: Int?
    @Published var lastXPDrop: XPDrop?

    private var saveTask: Task<Void, Never>?
    private var respawnTasks: [Int: Task<Void, Never>] = [:]

    // MARK: Derived

    var level: Int { XPTable.level(for: totalXP) }
    var region: RegionDef { GameData.region(id: currentRegionID) }
    var packCount: Int { inventory.compactMap { $0 }.count }
    var packIsFull: Bool { !inventory.contains(nil) }
    var isChopping: Bool { activeChopTreeID != nil }

    var achievementContext: AchievementContext {
        AchievementContext(
            stats: stats,
            level: level,
            ownedAxes: ownedAxes,
            totalRegionCount: GameData.regions.count
        )
    }

    // MARK: Init

    init() {
        let save = SaveManager.load() ?? PlayerSave.newGame
        totalXP = save.totalXP
        gold = save.gold
        inventory = save.inventory
        bank = save.bank
        ownedAxes = save.ownedAxes
        equippedAxe = save.equippedAxe
        currentRegionID = save.currentRegionID
        stats = save.stats
        unlockedAchievements = save.unlockedAchievements
        trees = Self.spawnTrees(for: GameData.region(id: save.currentRegionID))
        recordEvent(.info, "Welcome to \(GameData.region(id: save.currentRegionID).name).")
    }

    private static func spawnTrees(for region: RegionDef) -> [TreeState] {
        region.slots.enumerated().map { index, slot in
            let def = GameData.tree(for: slot.species)
            return TreeState(
                slotIndex: index,
                species: slot.species,
                logsRemaining: Int.random(in: def.logsMin...def.logsMax),
                respawnUntil: nil
            )
        }
    }

    // MARK: Chopping

    /// Tap intent from the forest: start chopping a tree, or stop if it
    /// is already the active one.
    func tapTree(_ id: Int) {
        guard trees.indices.contains(id) else { return }
        if activeChopTreeID == id {
            stopChopping()
            return
        }
        refreshRespawn(at: id)
        let tree = trees[id]
        let def = GameData.tree(for: tree.species)
        guard level >= def.levelReq else {
            recordEvent(.warning, "You need level \(def.levelReq) to chop \(def.species.displayName).")
            Haptics.reject()
            return
        }
        guard !tree.isDepleted else {
            recordEvent(.info, "That tree is regrowing.")
            return
        }
        guard !packIsFull else {
            recordEvent(.warning, "Your pack is full.")
            Haptics.reject()
            return
        }
        activeChopTreeID = id
        recordEvent(.info, "You swing your \(GameData.axe(for: equippedAxe).tier.displayName.lowercased()) axe at the \(def.species.displayName.lowercased())...")
    }

    func stopChopping() {
        activeChopTreeID = nil
    }

    /// One 0.6s chop attempt, driven by ChopEngine while chopping.
    func performChopTick() {
        guard let index = activeChopTreeID, trees.indices.contains(index) else {
            stopChopping()
            return
        }
        refreshRespawn(at: index)
        var tree = trees[index]
        guard !tree.isDepleted, tree.logsRemaining > 0 else {
            retargetOrStop(avoiding: index)
            return
        }
        guard !packIsFull else {
            recordEvent(.warning, "Your pack is full.")
            Haptics.reject()
            stopChopping()
            return
        }

        let def = GameData.tree(for: tree.species)
        let axe = GameData.axe(for: equippedAxe)
        let chance = ChopMath.successChance(level: level, tree: def, axe: axe)
        guard Double.random(in: 0..<1) < chance else { return }

        addToPack(tree.species)
        grantXP(def.xpPerLog)
        recordEvent(.chop, "You get some \(def.species.displayName.lowercased()) logs.")
        Haptics.chop()

        tree.logsRemaining -= 1
        if tree.logsRemaining <= 0 {
            tree.respawnUntil = Date().addingTimeInterval(def.respawnSeconds)
            trees[index] = tree
            recordEvent(.info, "The \(def.species.displayName.lowercased()) tree falls.")
            Haptics.thud()
            scheduleRespawnRefresh(at: index, after: def.respawnSeconds)
            retargetOrStop(avoiding: index)
        } else {
            trees[index] = tree
        }

        checkAchievements()
        scheduleSave()
    }

    /// After a tree falls, keep the idle loop going on the nearest
    /// available tree of the same species; stop if none.
    private func retargetOrStop(avoiding index: Int) {
        guard trees.indices.contains(index) else {
            stopChopping()
            return
        }
        let species = trees[index].species
        for i in trees.indices where i != index {
            refreshRespawn(at: i)
            if trees[i].species == species, !trees[i].isDepleted, trees[i].logsRemaining > 0 {
                activeChopTreeID = i
                return
            }
        }
        stopChopping()
    }

    /// Refreshes the tree state shortly after its respawn passes, so the
    /// stump visually regrows without waiting for a tap or tick. Stale
    /// tasks after travel are harmless: freshly spawned trees have no
    /// respawn date, so the refresh is a no-op.
    private func scheduleRespawnRefresh(at index: Int, after delay: TimeInterval) {
        respawnTasks[index]?.cancel()
        respawnTasks[index] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((delay + 0.1) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.refreshRespawn(at: index)
        }
    }

    /// If a depleted tree's respawn timer has passed, refill it.
    private func refreshRespawn(at index: Int) {
        guard trees.indices.contains(index) else { return }
        var tree = trees[index]
        if let until = tree.respawnUntil, until <= Date() {
            let def = GameData.tree(for: tree.species)
            tree.respawnUntil = nil
            tree.logsRemaining = Int.random(in: def.logsMin...def.logsMax)
            trees[index] = tree
        }
    }

    private func grantXP(_ amount: Double) {
        let before = level
        totalXP += amount
        lastXPDrop = XPDrop(amount: amount)
        let after = level
        if after > before {
            recordEvent(.levelUp, "Congratulations! Woodcutting level \(after).")
            Haptics.fanfare()
        }
    }

    private func addToPack(_ species: TreeSpecies) {
        guard let slot = inventory.firstIndex(of: nil) else { return }
        inventory[slot] = species
        stats.totalLogs += 1
        stats.logsBySpecies[species, default: 0] += 1
    }

    // MARK: Economy

    /// Sell every log of one species from the pack.
    func sell(species: TreeSpecies) {
        let count = inventory.filter { $0 == species }.count
        guard count > 0 else { return }
        let price = GameData.tree(for: species).sellPrice
        removeFromPack(species: species, count: count)
        earnGold(count * price)
        recordEvent(.info, "Sold \(count) \(species.displayName.lowercased()) logs for \(count * price) gp.")
        Haptics.thud()
        checkAchievements()
        scheduleSave()
    }

    func sellAllLogs() {
        for species in TreeSpecies.allCases {
            let count = inventory.filter { $0 == species }.count
            guard count > 0 else { continue }
            let price = GameData.tree(for: species).sellPrice
            removeFromPack(species: species, count: count)
            earnGold(count * price)
        }
        recordEvent(.info, "You sell your logs.")
        checkAchievements()
        scheduleSave()
    }

    private func earnGold(_ amount: Int) {
        guard amount > 0 else { return }
        gold += amount
        stats.lifetimeGold += amount
    }

    // MARK: Banking

    func depositAll() {
        var moved = 0
        for species in TreeSpecies.allCases {
            let count = inventory.filter { $0 == species }.count
            guard count > 0 else { continue }
            removeFromPack(species: species, count: count)
            addToBank(species: species, count: count)
            moved += count
        }
        guard moved > 0 else { return }
        recordEvent(.info, "Banked \(moved) logs.")
        Haptics.thud()
        scheduleSave()
    }

    func deposit(species: TreeSpecies) {
        let count = inventory.filter { $0 == species }.count
        guard count > 0 else { return }
        removeFromPack(species: species, count: count)
        addToBank(species: species, count: count)
        recordEvent(.info, "Banked \(count) \(species.displayName.lowercased()) logs.")
        scheduleSave()
    }

    func withdraw(species: TreeSpecies, count requested: Int) {
        guard let stackIndex = bank.firstIndex(where: { $0.species == species }) else { return }
        let freeSlots = inventory.filter { $0 == nil }.count
        let count = min(requested, bank[stackIndex].count, freeSlots)
        guard count > 0 else {
            recordEvent(.warning, "Your pack is full.")
            Haptics.reject()
            return
        }
        bank[stackIndex].count -= count
        if bank[stackIndex].count <= 0 {
            bank.remove(at: stackIndex)
        }
        for _ in 0..<count {
            if let slot = inventory.firstIndex(of: nil) {
                inventory[slot] = species
            }
        }
        scheduleSave()
    }

    /// Sell directly from the bank.
    func sellFromBank(species: TreeSpecies, count requested: Int) {
        guard let stackIndex = bank.firstIndex(where: { $0.species == species }) else { return }
        let count = min(requested, bank[stackIndex].count)
        guard count > 0 else { return }
        bank[stackIndex].count -= count
        if bank[stackIndex].count <= 0 {
            bank.remove(at: stackIndex)
        }
        let price = GameData.tree(for: species).sellPrice
        earnGold(count * price)
        recordEvent(.info, "Sold \(count) \(species.displayName.lowercased()) logs for \(count * price) gp.")
        checkAchievements()
        scheduleSave()
    }

    private func removeFromPack(species: TreeSpecies, count: Int) {
        var remaining = count
        for index in inventory.indices where remaining > 0 && inventory[index] == species {
            inventory[index] = nil
            remaining -= 1
        }
    }

    private func addToBank(species: TreeSpecies, count: Int) {
        if let index = bank.firstIndex(where: { $0.species == species }) {
            bank[index].count += count
        } else {
            bank.append(ItemStack(species: species, count: count))
            bank.sort { lhs, rhs in
                GameData.tree(for: lhs.species).levelReq < GameData.tree(for: rhs.species).levelReq
            }
        }
    }

    // MARK: Shop

    func buyAxe(_ tier: AxeTier) {
        let def = GameData.axe(for: tier)
        guard !ownedAxes.contains(tier) else { return }
        guard level >= def.levelReq else {
            recordEvent(.warning, "You need level \(def.levelReq) for the \(tier.displayName) axe.")
            Haptics.reject()
            return
        }
        guard gold >= def.cost else {
            recordEvent(.warning, "Not enough gold.")
            Haptics.reject()
            return
        }
        gold -= def.cost
        ownedAxes.insert(tier)
        equippedAxe = tier
        recordEvent(.info, "Bought and equipped the \(tier.displayName) axe!")
        Haptics.fanfare()
        checkAchievements()
        scheduleSave()
    }

    func equipAxe(_ tier: AxeTier) {
        guard ownedAxes.contains(tier), equippedAxe != tier else { return }
        equippedAxe = tier
        recordEvent(.info, "Equipped the \(tier.displayName) axe.")
        scheduleSave()
    }

    // MARK: Travel

    func travel(to regionID: String) {
        let destination = GameData.region(id: regionID)
        guard destination.id != currentRegionID else { return }
        guard level >= destination.levelReq else {
            recordEvent(.warning, "You need level \(destination.levelReq) to enter \(destination.name).")
            Haptics.reject()
            return
        }
        stopChopping()
        currentRegionID = destination.id
        trees = Self.spawnTrees(for: destination)
        stats.regionsVisited.insert(destination.id)
        recordEvent(.info, "You arrive in \(destination.name).")
        Haptics.thud()
        checkAchievements()
        scheduleSave()
    }

    // MARK: Achievements

    private func checkAchievements() {
        let context = achievementContext
        for achievement in GameData.achievements where !unlockedAchievements.contains(achievement.id) {
            if achievement.isUnlocked(context) {
                unlockedAchievements.insert(achievement.id)
                recordEvent(.achievement, "Achievement unlocked: \(achievement.name)!")
                Haptics.fanfare()
            }
        }
    }

    // MARK: Event log

    private func recordEvent(_ kind: EventLogEntry.Kind, _ text: String) {
        eventLog.append(EventLogEntry(kind: kind, text: text))
        if eventLog.count > GameData.eventLogCap {
            eventLog.removeFirst(eventLog.count - GameData.eventLogCap)
        }
    }

    // MARK: Persistence

    private var snapshot: PlayerSave {
        PlayerSave(
            schemaVersion: SaveManager.currentSchemaVersion,
            totalXP: totalXP,
            gold: gold,
            inventory: inventory,
            bank: bank,
            ownedAxes: ownedAxes,
            equippedAxe: equippedAxe,
            currentRegionID: currentRegionID,
            stats: stats,
            unlockedAchievements: unlockedAchievements
        )
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        SaveManager.save(snapshot)
    }

    func resetSave() {
        stopChopping()
        SaveManager.wipe()
        let fresh = PlayerSave.newGame
        totalXP = fresh.totalXP
        gold = fresh.gold
        inventory = fresh.inventory
        bank = fresh.bank
        ownedAxes = fresh.ownedAxes
        equippedAxe = fresh.equippedAxe
        currentRegionID = fresh.currentRegionID
        stats = fresh.stats
        unlockedAchievements = fresh.unlockedAchievements
        trees = Self.spawnTrees(for: GameData.region(id: fresh.currentRegionID))
        eventLog = []
        recordEvent(.info, "A fresh start. Welcome to \(region.name).")
        saveNow()
    }

    // MARK: Debug (Phase 1 only — removed once real screens land)

    func debugAddXP(_ amount: Double) {
        grantXP(amount)
        checkAchievements()
        scheduleSave()
    }

    func debugAddGold(_ amount: Int) {
        earnGold(amount)
        checkAchievements()
        scheduleSave()
    }
}
