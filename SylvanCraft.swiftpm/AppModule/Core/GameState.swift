import SwiftUI

/// Single source of truth for all game progress. Injected once at the app
/// root; every screen reads and mutates through it.
@MainActor
/// NSObject inheritance is required for CADisplayLink target/selector callbacks.
final class GameState: NSObject, ObservableObject {
    // MARK: Core progression (unchanged)
    @Published private(set) var totalXP: Double
    @Published private(set) var gold: Int
    @Published private(set) var inventory: [TreeSpecies?]
    @Published private(set) var bank: [ItemStack]
    @Published private(set) var ownedAxes: Set<AxeTier>
    @Published private(set) var equippedAxe: AxeTier
    @Published private(set) var stats: LifetimeStats
    @Published private(set) var unlockedAchievements: Set<String>
    @Published private(set) var eventLog: [EventLogEntry] = []
    @Published var lastXPDrop: XPDrop?
    /// Set once when the player approaches a tree above their Woodcutting
    /// level, so the HUD can surface a "you need level N" message.
    @Published var levelGateWarning: LevelGateWarning?
    /// The most recent chop-tick attempt (success or miss), used by
    /// `ForestSceneView.Coordinator` to retrigger the axe-swing animation
    /// exactly when a real gameplay tick resolves.
    @Published private(set) var lastChopStrike: ChopStrikeEvent?

    // MARK: World & player (new)
    @Published var player: PlayerState
    @Published var camera = Camera(center: .zero)
    @Published private(set) var worldTrees: [WorldTreeState] = []
    @Published private(set) var worldPickups: [PotionPickupState] = []
    @Published private(set) var loadedChunks: Set<ChunkCoord> = []

    /// The tree currently being chopped, if any.
    @Published private(set) var activeChopTreeKey: String?

    /// Transient vitals — not persisted (no `PlayerSave` field). Reset to
    /// full on every launch.
    @Published private(set) var stamina: Double = GameData.maxStamina

    /// Expiry of an active Woodcutting Potion boost, if any. Transient —
    /// not persisted, same as `stamina` — so a boost resets on relaunch.
    @Published private(set) var activeBoostExpiresAt: Date?

    /// When "Watch Ad" becomes available again after an ad-granted boost
    /// ends. Transient — not persisted, same as `activeBoostExpiresAt`.
    @Published private(set) var adBoostCooldownExpiresAt: Date?

    /// Distance traveled since last snapshot (for wanderer achievement).
    private var farthestDistanceFromOrigin: Double = 0

    private var saveTask: Task<Void, Never>?
    private var updateLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var lastChopTickTime: CFTimeInterval = 0
    private var lastAutoSaveTime: CFTimeInterval = 0
    private var respawnTasks: [String: Task<Void, Never>] = [:]

    // MARK: Derived

    var level: Int { XPTable.level(for: totalXP) }
    var packCount: Int { inventory.compactMap { $0 }.count }
    var packIsFull: Bool { !inventory.contains(nil) }
    var isChopping: Bool { activeChopTreeKey != nil }
    var isExhausted: Bool { stamina <= 0 }

    /// Whether a Woodcutting Potion boost is currently in effect.
    var isWoodcuttingBoostActive: Bool {
        guard let activeBoostExpiresAt else { return false }
        return activeBoostExpiresAt > Date()
    }

    /// Whether "Watch Ad" can be used: no boost currently running and the
    /// post-boost cooldown (if any) has elapsed.
    var isAdBoostAvailable: Bool {
        guard !isWoodcuttingBoostActive else { return false }
        guard let adBoostCooldownExpiresAt else { return true }
        return adBoostCooldownExpiresAt <= Date()
    }

    /// Woodcutting level used for gameplay gating (tree unlocks, chop
    /// success chance): the real XP-based `level` plus the potion boost
    /// while active, clamped to the max level. The HUD's displayed level
    /// number stays literal — only this drives gameplay checks.
    var effectiveLevel: Int {
        guard isWoodcuttingBoostActive else { return level }
        return min(level + GameData.woodcuttingPotionLevelBoost, XPTable.maxLevel)
    }

    var achievementContext: AchievementContext {
        AchievementContext(
            stats: stats,
            level: level,
            ownedAxes: ownedAxes,
            maxDistanceFromOrigin: farthestDistanceFromOrigin
        )
    }

    // MARK: Init

    override init() {
        let save = SaveManager.load() ?? PlayerSave.newGame
        totalXP = save.totalXP
        gold = save.gold
        inventory = save.inventory
        bank = save.bank
        ownedAxes = save.ownedAxes
        equippedAxe = save.equippedAxe
        stats = save.stats
        unlockedAchievements = save.unlockedAchievements

        // Restore or create player at saved position.
        let pos = save.playerPosition
        player = PlayerState(position: pos)
        farthestDistanceFromOrigin = hypot(pos.x, pos.y)

        // Generate initial chunks around the player.
        worldTrees = ChunkManager.generateInitial(around: pos)
        worldPickups = ChunkManager.generateInitialPickups(around: pos)
        loadedChunks = ChunkManager.loadedChunkSet(around: pos)

        super.init()

        // Snap camera to player (no lerp on init).
        camera.snap(to: pos)

        recordEvent(.info, "Welcome to Sylvan Craft. Drag to explore the forest.")

        // Start the 60 fps update loop.
        lastUpdateTime = CACurrentMediaTime()
        updateLink = CADisplayLink(target: self, selector: #selector(onFrame))
        updateLink?.add(to: .main, forMode: .common)
    }

    deinit {
        updateLink?.invalidate()
    }

    // MARK: Per-frame update (movement + proximity chopping)

    @objc private func onFrame(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let dt = CGFloat(now - lastUpdateTime)
        lastUpdateTime = now
        guard dt > 0, dt < 0.1 else { return } // guard against huge jumps

        // --- Movement ---
        let speed = GameData.playerWalkSpeed * (isExhausted ? GameData.exhaustedSpeedMultiplier : 1)
        var moved = false

        if player.velocity.x != 0 || player.velocity.y != 0 {
            // Normalize to prevent diagonal speed boost.
            let mag = hypot(player.velocity.x, player.velocity.y)
            let nx = mag > 0.001 ? player.velocity.x / mag : 0
            let ny = mag > 0.001 ? player.velocity.y / mag : 0

            player.position.x += nx * speed * dt
            player.position.y += ny * speed * dt

            // Turn to face the direction of travel. `player` sits behind
            // `@Published`, so every field write is a separate publish —
            // guard on an actual (meaningful) change so holding a
            // direction doesn't keep republishing the same value. The
            // diff is wrapped into (-pi, pi] since `facingAngle` can sit
            // near the ±pi seam even when the new heading is nearby.
            let heading = atan2(nx, ny)
            var angleDiff = heading - player.facingAngle
            angleDiff = atan2(sin(angleDiff), cos(angleDiff))
            if abs(angleDiff) > 0.01 {
                player.facingAngle = heading
            }

            // Track farthest distance.
            let dist = hypot(player.position.x, player.position.y)
            if dist > farthestDistanceFromOrigin {
                farthestDistanceFromOrigin = dist
            }

            moved = true
            if player.animation != .walking { player.animation = .walking }
            if player.dwellStart != nil { player.dwellStart = nil }
            if player.dwellTargetKey != nil { player.dwellTargetKey = nil }

            // Stop chopping if we moved away.
            if isChopping {
                stopChopping()
            }
        } else {
            let idleAnimation: PlayerAnimation = isChopping ? .chopping : .idle
            if player.animation != idleAnimation { player.animation = idleAnimation }
        }

        // --- Chunk loading ---
        let newChunks = ChunkManager.loadedChunkSet(around: player.position)
        if newChunks != loadedChunks {
            let added = newChunks.subtracting(loadedChunks)
            for coord in added {
                let chunk = WorldGenerator.generateChunk(coord: coord)
                worldTrees.append(contentsOf: chunk.trees)
                worldPickups.append(contentsOf: PickupGenerator.generate(for: coord))
            }
            // Unload far chunks.
            let removed = loadedChunks.subtracting(newChunks)
            if !removed.isEmpty {
                let removedKeys = Set(removed.flatMap { coord in
                    worldTrees.filter { $0.key.hasPrefix("\(coord.x):\(coord.y):") }.map(\.key)
                })
                worldTrees.removeAll { removedKeys.contains($0.key) }

                let removedPickupKeys = Set(removed.flatMap { coord in
                    worldPickups.filter { $0.key.hasPrefix("potion:\(coord.x):\(coord.y):") }.map(\.key)
                })
                worldPickups.removeAll { removedPickupKeys.contains($0.key) }
            }
            loadedChunks = newChunks
        }

        // Refresh respawned trees and potion pickups.
        refreshAllRespawning()
        refreshPotionRespawning()

        // Clear an expired potion boost.
        if let expiresAt = activeBoostExpiresAt, expiresAt <= Date() {
            activeBoostExpiresAt = nil
            recordEvent(.info, "Your woodcutting potion has worn off.")
        }

        // --- Proximity chopping ---
        tickProximityChopping(now: now, dt: dt, moved: moved)

        // --- Potion pickups ---
        tickPotionPickups()

        // --- Stamina ---
        updateVitals(dt: dt)

        // --- Camera follow ---
        // Skipped entirely once converged (see `Camera.convergenceEpsilon`)
        // so an idle camera doesn't keep republishing `camera` every frame.
        let camDist = hypot(player.position.x - camera.center.x, player.position.y - camera.center.y)
        if camDist > Camera.convergenceEpsilon {
            camera.follow(target: player.position)
        }

        // --- Auto-save periodically ---
        // A timestamp check rather than `scheduleSave()`'s debounce Task —
        // calling that every frame would cancel/reschedule it 60–120
        // times a second and the 2s delay would never actually elapse.
        if now - lastAutoSaveTime > GameData.autoSaveInterval {
            lastAutoSaveTime = now
            saveNow()
        }
    }

    /// Stamina drains while active (walking or chopping) and regenerates
    /// while idle.
    private func updateVitals(dt: CGFloat) {
        let dtSeconds = Double(dt)

        if player.animation == .idle {
            stamina = min(GameData.maxStamina, stamina + GameData.staminaRegenPerSecond * dtSeconds)
        } else {
            stamina = max(0, stamina - GameData.staminaDrainPerSecond * dtSeconds)
        }
    }

    // MARK: Proximity chopping

    private func tickProximityChopping(now: CFTimeInterval, dt: CGFloat, moved: Bool) {
        // If already chopping, just run chop ticks.
        if let key = activeChopTreeKey, let idx = worldTrees.firstIndex(where: { $0.key == key }) {
            // Check if player moved too far from the active tree.
            let tree = worldTrees[idx]
            let dist = hypot(tree.worldPosition.x - player.position.x,
                             tree.worldPosition.y - player.position.y)
            if dist > GameData.proximityRadius * 1.5 {
                stopChopping()
                return
            }
            // Run chop ticks on interval, slower while exhausted.
            let interval = GameData.tickInterval * (isExhausted ? GameData.exhaustedTickMultiplier : 1)
            if now - lastChopTickTime >= interval {
                lastChopTickTime = now
                performChopTick()
            }
            return
        }

        // Not chopping — check for nearby trees.
        guard !packIsFull else { return }

        // Find the nearest eligible tree within proximity radius, and
        // separately the nearest tree that's in range but above the
        // player's Woodcutting level, so we can warn about it if it's all
        // that's nearby.
        var best: (key: String, dist: CGFloat, species: TreeSpecies)? = nil
        var nearestBlocked: (key: String, dist: CGFloat, species: TreeSpecies, levelReq: Int)? = nil
        for tree in worldTrees {
            guard !tree.isDepleted, tree.logsRemaining > 0 else { continue }
            let def = GameData.tree(for: tree.species)
            let dist = hypot(tree.worldPosition.x - player.position.x,
                             tree.worldPosition.y - player.position.y)
            guard dist <= GameData.proximityRadius else { continue }

            guard effectiveLevel >= def.levelReq else {
                if nearestBlocked == nil || dist < nearestBlocked!.dist {
                    nearestBlocked = (tree.key, dist, tree.species, def.levelReq)
                }
                continue
            }
            if best == nil || dist < best!.dist {
                best = (tree.key, dist, tree.species)
            }
        }

        guard let best else {
            // No eligible tree nearby — reset dwell.
            player.dwellStart = nil
            player.dwellTargetKey = nil

            if let nearestBlocked {
                if player.blockedTreeKey != nearestBlocked.key {
                    player.blockedTreeKey = nearestBlocked.key
                    levelGateWarning = LevelGateWarning(species: nearestBlocked.species, requiredLevel: nearestBlocked.levelReq)
                    Haptics.reject()
                }
            } else {
                player.blockedTreeKey = nil
            }
            return
        }

        // An eligible tree is in range — clear any stale blocked-tree state.
        player.blockedTreeKey = nil

        // Check if dwelling on the same tree.
        if player.dwellTargetKey == best.key {
            if let start = player.dwellStart,
               Date().timeIntervalSince(start) >= GameData.dwellDuration
            {
                // Begin chopping!
                startChopping(treeKey: best.key, species: best.species)
            }
        } else {
            // New tree entered range — start dwell timer.
            player.dwellTargetKey = best.key
            player.dwellStart = Date()
        }
    }

    private func startChopping(treeKey: String, species: TreeSpecies) {
        guard let idx = worldTrees.firstIndex(where: { $0.key == treeKey }) else { return }
        let tree = worldTrees[idx]
        let def = GameData.tree(for: tree.species)
        guard !tree.isDepleted, !packIsFull, effectiveLevel >= def.levelReq else { return }

        activeChopTreeKey = treeKey
        player.animation = .chopping
        lastChopTickTime = CACurrentMediaTime()
        recordEvent(.info, "You swing your \(GameData.axe(for: equippedAxe).tier.displayName.lowercased()) axe at the \(def.species.displayName.lowercased())...")
    }

    func stopChopping() {
        activeChopTreeKey = nil
        if player.animation == .chopping {
            player.animation = .idle
        }
        player.dwellStart = nil
        player.dwellTargetKey = nil
    }

    /// One chop attempt. Same core logic as before, but world-tree aware.
    func performChopTick() {
        guard let key = activeChopTreeKey,
              let idx = worldTrees.firstIndex(where: { $0.key == key })
        else {
            stopChopping()
            return
        }

        var tree = worldTrees[idx]
        let def = GameData.tree(for: tree.species)

        guard !tree.isDepleted, tree.logsRemaining > 0 else {
            stopChopping()
            retargetNearby()
            return
        }
        guard !packIsFull else {
            recordEvent(.warning, "Your pack is full.")
            Haptics.reject()
            stopChopping()
            return
        }

        let axe = GameData.axe(for: equippedAxe)
        let chance = ChopMath.successChance(level: effectiveLevel, tree: def, axe: axe)
        let success = Double.random(in: 0..<1) < chance
        // Published on every real attempt (hit or miss) so the axe visibly
        // swings every tick, but impact feedback (wood chips/tree shake)
        // only fires when `success` is true.
        lastChopStrike = ChopStrikeEvent(treeKey: key, success: success, worldPosition: tree.worldPosition)
        guard success else { return }

        addToPack(tree.species)
        grantXP(def.xpPerLog)
        recordEvent(.chop, "You get some \(def.species.displayName.lowercased()) logs.")
        Haptics.chop()

        tree.logsRemaining -= 1
        if tree.logsRemaining <= 0 {
            tree.respawnUntil = Date().addingTimeInterval(def.respawnSeconds)
            worldTrees[idx] = tree
            recordEvent(.info, "The \(def.species.displayName.lowercased()) tree falls.")
            Haptics.thud()
            scheduleRespawnRefresh(for: key, after: def.respawnSeconds)
            stopChopping()
            retargetNearby()
        } else {
            worldTrees[idx] = tree
        }

        checkAchievements()
        scheduleSave()
    }

    /// After a tree falls, find the nearest available tree of any species.
    private func retargetNearby() {
        var best: (key: String, dist: CGFloat)? = nil
        for tree in worldTrees {
            guard !tree.isDepleted, tree.logsRemaining > 0 else { continue }
            guard effectiveLevel >= GameData.tree(for: tree.species).levelReq else { continue }
            let dist = hypot(tree.worldPosition.x - player.position.x,
                             tree.worldPosition.y - player.position.y)
            guard dist <= GameData.proximityRadius * 1.35 else { continue }
            if best == nil || dist < best!.dist {
                best = (tree.key, dist)
            }
        }
        if let best {
            // Begin dwell phase on the new tree.
            player.dwellTargetKey = best.key
            player.dwellStart = Date()
        }
    }

    // MARK: Respawn helpers

    private func scheduleRespawnRefresh(for key: String, after delay: TimeInterval) {
        respawnTasks[key]?.cancel()
        respawnTasks[key] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((delay + 0.1) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.refreshRespawn(for: key)
        }
    }

    private func refreshRespawn(for key: String) {
        guard let idx = worldTrees.firstIndex(where: { $0.key == key }) else { return }
        var tree = worldTrees[idx]
        if let until = tree.respawnUntil, until <= Date() {
            let def = GameData.tree(for: tree.species)
            tree.respawnUntil = nil
            tree.logsRemaining = Int.random(in: def.logsMin...def.logsMax)
            worldTrees[idx] = tree
        }
    }

    private func refreshAllRespawning() {
        let now = Date()
        for i in worldTrees.indices {
            if let until = worldTrees[i].respawnUntil, until <= now {
                let def = GameData.tree(for: worldTrees[i].species)
                worldTrees[i].respawnUntil = nil
                worldTrees[i].logsRemaining = Int.random(in: def.logsMin...def.logsMax)
            }
        }
    }

    // MARK: Potion pickups

    /// Auto-collects any non-collected potion pickup within
    /// `GameData.potionPickupRadius` of the player.
    private func tickPotionPickups() {
        for idx in worldPickups.indices {
            guard !worldPickups[idx].isCollected else { continue }
            let pickup = worldPickups[idx]
            let dist = hypot(pickup.worldPosition.x - player.position.x,
                             pickup.worldPosition.y - player.position.y)
            guard dist <= GameData.potionPickupRadius else { continue }
            collectPotionPickup(idx)
        }
    }

    /// Consuming a potion is immediate: the pickup vanishes (to respawn
    /// later) and the boost timer resets to a full 5 minutes rather than
    /// stacking with any remaining time.
    private func collectPotionPickup(_ idx: Int) {
        worldPickups[idx].respawnUntil = Date().addingTimeInterval(GameData.potionRespawnSeconds)
        activeBoostExpiresAt = Date().addingTimeInterval(GameData.woodcuttingPotionDuration)
        recordEvent(.info, "You drink the woodcutting potion. +\(GameData.woodcuttingPotionLevelBoost) Woodcutting for 5 minutes!")
        Haptics.fanfare()
    }

    // MARK: Ads

    /// Called once the simulated "watch ad" countdown completes. Grants
    /// the same reward as a Woodcutting Potion (resets to a full 5
    /// minutes rather than stacking), then locks "Watch Ad" behind a
    /// cooldown that starts counting once the boost itself ends.
    func grantAdBoost() {
        let boostExpiry = Date().addingTimeInterval(GameData.woodcuttingPotionDuration)
        activeBoostExpiresAt = boostExpiry
        adBoostCooldownExpiresAt = boostExpiry.addingTimeInterval(GameData.adBoostCooldownDuration)
        recordEvent(.info, "Ad reward claimed! +\(GameData.woodcuttingPotionLevelBoost) Woodcutting for 5 minutes!")
        Haptics.fanfare()
    }

    private func refreshPotionRespawning() {
        let now = Date()
        for i in worldPickups.indices {
            if let until = worldPickups[i].respawnUntil, until <= now {
                worldPickups[i].respawnUntil = nil
            }
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
            playerPosition: player.position,
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
        stats = fresh.stats
        unlockedAchievements = fresh.unlockedAchievements

        player = PlayerState(position: .zero)
        farthestDistanceFromOrigin = 0
        camera.snap(to: .zero)

        worldTrees = ChunkManager.generateInitial(around: .zero)
        worldPickups = ChunkManager.generateInitialPickups(around: .zero)
        loadedChunks = ChunkManager.loadedChunkSet(around: .zero)
        activeBoostExpiresAt = nil

        eventLog = []
        recordEvent(.info, "A fresh start. Welcome to the forest.")
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
