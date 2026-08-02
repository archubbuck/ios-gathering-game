import QuartzCore
import SceneKit
import SwiftUI

/// The 3D forest viewport: a low-poly SceneKit scene (ground, lights,
/// camera) rendered via `UIViewRepresentable`. Node transforms are pushed
/// from `updateUIView(_:context:)` — guaranteed main-thread, fired on every
/// `@Published` `GameState` change — rather than a
/// `SCNSceneRendererDelegate` callback, which would run on SceneKit's
/// rendering thread and read `@MainActor` state unsafely.
struct ForestSceneView: UIViewRepresentable {
    @EnvironmentObject private var game: GameState
    @ObservedObject var hudBridge: SceneHUDBridge

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = context.coordinator.scene
        // Background must match `scene.fogColor` so fogged-out geometry
        // dissolves seamlessly into the backdrop.
        scnView.backgroundColor = SceneKitConversions.uiColor(TimberlineTheme.Scene3D.haze)
        scnView.antialiasingMode = .multisampling2X
        // Transforms are pushed explicitly from `updateUIView` on every
        // `GameState` change, so SceneKit only needs to render on demand —
        // `rendersContinuously` forced a full render pass every display
        // refresh (60–120/s) from the moment the view appeared, which was
        // a major contributor to startup GPU/thermal pressure.
        scnView.rendersContinuously = false
        scnView.pointOfView = context.coordinator.cameraNode
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        context.coordinator.diffTrees(game: game)
        context.coordinator.updatePlayer(game: game)
        context.coordinator.updateCamera(game: game)
        context.coordinator.updateGround(playerPosition: game.player.position)
        hudBridge.update(game: game, scnView: scnView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        let scene = SCNScene()
        let cameraNode = SCNNode()
        let treeContainer = SCNNode()
        let decorationContainer = SCNNode()
        let pickupContainer = SCNNode()
        private lazy var groundStreamer = WorldTreeStreamer(sceneRoot: scene.rootNode)

        /// Fixed world-space offset of the camera from its look-at target,
        /// giving the isometric-style downward angled view. Distance to
        /// target is preserved at ~1110 (`sqrt(555^2 + 961^2)`); the split
        /// between height and depth gives a 30° elevation above the
        /// horizon (`atan(555/961)`), a shallower/more side-on read than
        /// the previous 54° (`atan(900/650)`). See `baseOrthographicScale`
        /// for how the framing was re-tuned to match.
        static let cameraOffset = SCNVector3(0, 555, 961)

        /// Live tree nodes keyed by `WorldTreeState.key`, diffed against the
        /// render radius on a wall-clock throttle (not every frame — see
        /// `diffTrees`).
        private var treeNodes: [String: SCNNode] = [:]
        private var lastTreeDiffTime: CFTimeInterval = 0
        private let treeDiffInterval: CFTimeInterval = 0.25

        /// The single player node, built lazily on the first `updatePlayer`
        /// call (needs `game.equippedAxe`, unavailable in `init`).
        private var playerNode: SCNNode?
        private var lastAxeTier: AxeTier?
        /// The last `ChopStrikeEvent.id` the chop-swing ensemble has already
        /// reacted to — a change here (or no swing currently animating)
        /// retriggers `applyChopSwing`, keeping the visible swing in
        /// lockstep with `GameState`'s real chop-tick cadence.
        private var lastHandledStrikeID: UUID?
        /// True from the moment a swing is started until this Coordinator
        /// has issued the one-shot `easeChopToRest` for it — guards against
        /// re-issuing the ease every frame while its action is still
        /// finishing (which would never let it complete).
        private var isChopSwingActive = false

        /// Purely visual chunk decorations (rocks, dirt patches), one
        /// container node per loaded chunk, diffed at chunk granularity.
        private var decorationChunks: [ChunkCoord: SCNNode] = [:]
        /// A handful of shared decoration geometries reused across all
        /// instances (size differences come from node scale).
        private var decorationGeometryCache: [String: SCNGeometry] = [:]

        /// Live potion pickup nodes keyed by `PotionPickupState.key`,
        /// diffed alongside trees on the same throttle in `diffTrees`.
        private var pickupNodes: [String: SCNNode] = [:]

        init() {
            setUpLights()
            setUpCamera()
            setUpAtmosphere()
            treeContainer.name = "trees"
            scene.rootNode.addChildNode(treeContainer)
            decorationContainer.name = "decorations"
            scene.rootNode.addChildNode(decorationContainer)
            pickupContainer.name = "pickups"
            scene.rootNode.addChildNode(pickupContainer)
        }

        /// Adds/removes/updates tree nodes so only trees within
        /// `GameData.treeRenderRadius` of the player carry an `SCNNode`,
        /// with `treeRenderHysteresis` slack to avoid boundary flicker.
        /// Throttled by wall-clock time since `updateUIView`'s cadence
        /// isn't guaranteed fixed.
        func diffTrees(game: GameState) {
            let now = CACurrentMediaTime()
            guard now - lastTreeDiffTime > treeDiffInterval else { return }
            lastTreeDiffTime = now

            let playerPos = game.player.position
            diffDecorations(playerPosition: playerPos)
            diffPickups(game: game)
            let renderRadius = GameData.treeRenderRadius
            let despawnRadius = renderRadius + GameData.treeRenderHysteresis
            let renderRadiusSq = renderRadius * renderRadius
            let despawnRadiusSq = despawnRadius * despawnRadius

            var seenKeys = Set<String>()
            for tree in game.worldTrees {
                let dx = tree.worldPosition.x - playerPos.x
                let dy = tree.worldPosition.y - playerPos.y
                let distSq = dx * dx + dy * dy

                if distSq <= renderRadiusSq {
                    seenKeys.insert(tree.key)
                    upsertTreeNode(for: tree, level: game.effectiveLevel)
                } else if distSq > despawnRadiusSq {
                    if let existing = treeNodes[tree.key] {
                        existing.removeFromParentNode()
                        treeNodes.removeValue(forKey: tree.key)
                    }
                } else if treeNodes[tree.key] != nil {
                    // Inside the hysteresis band: keep the existing node,
                    // stale state and all, until it's fully out of range.
                    seenKeys.insert(tree.key)
                }
            }

            // Trees that vanished outright (respawned key reused elsewhere,
            // chunk unloaded) rather than just walking out of range.
            for key in treeNodes.keys where !seenKeys.contains(key) {
                treeNodes[key]?.removeFromParentNode()
                treeNodes.removeValue(forKey: key)
            }
        }

        private func upsertTreeNode(for tree: WorldTreeState, level: Int) {
            let locked = level < GameData.tree(for: tree.species).levelReq
            let desiredName = tree.isDepleted ? "stump" : (locked ? "tree-locked" : "tree")

            if let existing = treeNodes[tree.key] {
                if existing.name == desiredName {
                    existing.position = SceneKitConversions.vector(tree.worldPosition)
                    return
                }
                existing.removeFromParentNode()
            }

            // Per-instance variety, seeded from the stable tree key (an
            // FNV-1a fold — never `String.hashValue`, which is randomized
            // per launch) so a tree keeps its exact shape/yaw/scale across
            // despawn/respawn, and its stump inherits the same footprint.
            var seed: UInt64 = 0xCBF2_9CE4_8422_2325
            for byte in tree.key.utf8 {
                seed = (seed ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
            }
            var rng = SeededRandom(seed: seed)
            let variant = Int(rng.next() % UInt64(TreeGeometryFactory.variantCount))
            let yaw = rng.nextFloat() * 2 * .pi
            let scale = 0.9 + rng.nextFloat() * 0.25

            let node = tree.isDepleted
                ? TreeGeometryFactory.makeStumpNode(species: tree.species, variant: variant)
                : TreeGeometryFactory.makeTreeNode(species: tree.species, locked: locked, variant: variant)
            node.name = desiredName
            node.position = SceneKitConversions.vector(tree.worldPosition)
            node.eulerAngles.y = yaw
            node.scale = SCNVector3(scale, scale, scale)
            treeContainer.addChildNode(node)
            treeNodes[tree.key] = node
        }

        /// Adds/removes potion pickup nodes so only non-collected pickups
        /// within the tree render radius carry an `SCNNode`. Uses the same
        /// render/hysteresis radii as trees — pickups are sparse (at most
        /// one per chunk) so no separate distance budget is needed.
        private func diffPickups(game: GameState) {
            let playerPos = game.player.position
            let renderRadius = GameData.treeRenderRadius
            let despawnRadius = renderRadius + GameData.treeRenderHysteresis
            let renderRadiusSq = renderRadius * renderRadius
            let despawnRadiusSq = despawnRadius * despawnRadius

            var seenKeys = Set<String>()
            for pickup in game.worldPickups {
                let dx = pickup.worldPosition.x - playerPos.x
                let dy = pickup.worldPosition.y - playerPos.y
                let distSq = dx * dx + dy * dy

                if pickup.isCollected {
                    if let existing = pickupNodes[pickup.key] {
                        existing.removeFromParentNode()
                        pickupNodes.removeValue(forKey: pickup.key)
                    }
                    continue
                }

                if distSq <= renderRadiusSq {
                    seenKeys.insert(pickup.key)
                    if pickupNodes[pickup.key] == nil {
                        let node = PickupNodeFactory.makePotionNode()
                        node.position = SceneKitConversions.vector(pickup.worldPosition)
                        pickupContainer.addChildNode(node)
                        pickupNodes[pickup.key] = node
                    }
                } else if distSq > despawnRadiusSq {
                    if let existing = pickupNodes[pickup.key] {
                        existing.removeFromParentNode()
                        pickupNodes.removeValue(forKey: pickup.key)
                    }
                } else if pickupNodes[pickup.key] != nil {
                    seenKeys.insert(pickup.key)
                }
            }

            for key in pickupNodes.keys where !seenKeys.contains(key) {
                pickupNodes[key]?.removeFromParentNode()
                pickupNodes.removeValue(forKey: key)
            }
        }

        /// Keeps a 3×3 chunk neighborhood of decoration containers alive
        /// around the player (3600-unit span, comfortably covering the
        /// 1400-unit tree render radius). Runs on `diffTrees`' throttle.
        private func diffDecorations(playerPosition: CGPoint) {
            let chunkX = Int(floor(playerPosition.x / GameData.chunkSize))
            let chunkY = Int(floor(playerPosition.y / GameData.chunkSize))
            var desired = Set<ChunkCoord>()
            for dx in -1...1 {
                for dy in -1...1 {
                    desired.insert(ChunkCoord(x: chunkX + dx, y: chunkY + dy))
                }
            }

            for coord in desired where decorationChunks[coord] == nil {
                let container = SCNNode()
                for instance in DecorationGenerator.decorations(for: coord) {
                    container.addChildNode(makeDecorationNode(instance))
                }
                decorationContainer.addChildNode(container)
                decorationChunks[coord] = container
            }
            for (coord, node) in decorationChunks where !desired.contains(coord) {
                node.removeFromParentNode()
                decorationChunks.removeValue(forKey: coord)
            }
        }

        private func makeDecorationNode(_ instance: DecorationInstance) -> SCNNode {
            let node: SCNNode
            switch instance.kind {
            case .rock(let radius):
                // 3 shared boulder shapes; per-instance size via node scale.
                let variant = Int(instance.seed % 3)
                let geometry = decorationGeometry(key: "rock\(variant)") {
                    LowPolyGeometry.facetedRock(
                        radius: 10,
                        seed: 0xD0C0 &+ UInt64(variant),
                        baseColor: TimberlineTheme.Scene3D.rock,
                        highlightColor: TimberlineTheme.Scene3D.rockLight
                    )
                }
                node = SCNNode(geometry: geometry)
                let scale = SceneKitConversions.float(radius) / 10
                node.scale = SCNVector3(scale, scale, scale)
                // Slightly raised so most of the boulder shows while the
                // jittered underside stays buried.
                node.position = SceneKitConversions.vector(
                    instance.worldPosition, height: 0.15 * radius
                )

            case .dirtPatch(let radius, let light):
                let variant = Int(instance.seed % 3)
                let key = light ? "dirtLight\(variant)" : "dirt\(variant)"
                let geometry = decorationGeometry(key: key) {
                    LowPolyGeometry.groundPatch(
                        radius: 10,
                        seed: 0xD117 &+ UInt64(variant),
                        color: light ? TimberlineTheme.Scene3D.dirtLight : TimberlineTheme.Scene3D.dirt
                    )
                }
                node = SCNNode(geometry: geometry)
                let scale = SceneKitConversions.float(radius) / 10
                node.scale = SCNVector3(scale, scale, scale)
                // Floated just above the ground plane to avoid z-fighting;
                // flat polygons cast no useful shadow.
                node.position = SceneKitConversions.vector(instance.worldPosition, height: 1.5)
                node.castsShadow = false

            case .pebble(let radius):
                let geometry = decorationGeometry(key: "pebble") {
                    LowPolyGeometry.facetedRock(
                        radius: 10,
                        seed: 0x9EBB1E,
                        baseColor: TimberlineTheme.Scene3D.pebble,
                        highlightColor: TimberlineTheme.Scene3D.dirtLight
                    )
                }
                node = SCNNode(geometry: geometry)
                let scale = SceneKitConversions.float(radius) / 10
                node.scale = SCNVector3(scale, scale, scale)
                node.position = SceneKitConversions.vector(
                    instance.worldPosition, height: 0.15 * radius
                )
            }
            node.eulerAngles.y = SceneKitConversions.float(instance.rotation)
            return node
        }

        private func decorationGeometry(key: String, make: () -> SCNGeometry) -> SCNGeometry {
            if let cached = decorationGeometryCache[key] { return cached }
            let geometry = make()
            decorationGeometryCache[key] = geometry
            return geometry
        }

        /// Pushes position/facing/animation state onto the player node every
        /// call. Builds the node on first use and rebuilds only the axe
        /// geometry (not the whole hierarchy) when the equipped tier changes.
        func updatePlayer(game: GameState) {
            let node: SCNNode
            if let existing = playerNode {
                node = existing
            } else {
                node = PlayerNodeFactory.makeNode(axeTier: game.equippedAxe)
                scene.rootNode.addChildNode(node)
                playerNode = node
                lastAxeTier = game.equippedAxe
            }

            node.position = SceneKitConversions.vector(game.player.position)
            // World-space `facingAngle` (atan2(dx, dy)) maps directly onto
            // a SceneKit yaw: world x → scene X, world y → scene Z, so
            // rotating the root about Y by that angle turns the character
            // to face the same direction on the XZ ground plane.
            node.eulerAngles.y = SceneKitConversions.float(game.player.facingAngle)

            guard let body = node.childNode(withName: PlayerNodeFactory.NodeName.body, recursively: true),
                  let head = node.childNode(withName: PlayerNodeFactory.NodeName.head, recursively: true),
                  let armPivot = node.childNode(withName: PlayerNodeFactory.NodeName.armPivot, recursively: true),
                  let forearmPivot = node.childNode(withName: PlayerNodeFactory.NodeName.forearmPivot, recursively: true),
                  let armPivotLeft = node.childNode(withName: PlayerNodeFactory.NodeName.armPivotLeft, recursively: true),
                  let forearmPivotLeft = node.childNode(withName: PlayerNodeFactory.NodeName.forearmPivotLeft, recursively: true),
                  let legPivotLeft = node.childNode(withName: PlayerNodeFactory.NodeName.legPivotLeft, recursively: true),
                  let legPivotRight = node.childNode(withName: PlayerNodeFactory.NodeName.legPivotRight, recursively: true)
            else { return }

            if lastAxeTier != game.equippedAxe {
                PlayerNodeFactory.rebuildAxe(in: forearmPivot, tier: game.equippedAxe)
                lastAxeTier = game.equippedAxe
            }

            // --- Chop swing: retriggered on the real gameplay tick, not a
            // free-running loop. `armPivot` stands in for the whole
            // 5-node ensemble since all five are started/stopped under
            // the same `chopSwingKey`.
            let isChopping = game.player.animation == .chopping
            if isChopping {
                let strikeChanged = game.lastChopStrike?.id != lastHandledStrikeID
                let isAnimating = armPivot.action(forKey: PlayerNodeFactory.chopSwingKey) != nil
                if strikeChanged || !isAnimating {
                    lastHandledStrikeID = game.lastChopStrike?.id
                    let interval = GameData.tickInterval * (game.isExhausted ? GameData.exhaustedTickMultiplier : 1)
                    PlayerNodeFactory.applyChopSwing(
                        body: body, armPivot: armPivot, forearmPivot: forearmPivot,
                        armPivotLeft: armPivotLeft, forearmPivotLeft: forearmPivotLeft,
                        duration: interval
                    )
                    if strikeChanged, let event = game.lastChopStrike, event.success {
                        playChopImpact(event: event, game: game)
                    }
                }
                isChopSwingActive = true
            } else if isChopSwingActive {
                // One-shot: ease to rest, then let this flag stay false so
                // subsequent frames don't keep restarting the ease before
                // it can ever finish.
                PlayerNodeFactory.easeChopToRest(
                    body: body, armPivot: armPivot, forearmPivot: forearmPivot,
                    armPivotLeft: armPivotLeft, forearmPivotLeft: forearmPivotLeft
                )
                isChopSwingActive = false
            }

            // Hip-pivot leg swing; zeroing when idle doubles as the reset,
            // so no action bookkeeping is needed. Legs are never touched
            // by the chop ensemble, so this always runs unconditionally.
            let walking = game.player.animation == .walking
            let walkPhase = CACurrentMediaTime() * 8
            let legSwing = walking ? Float(sin(walkPhase)) * 0.5 : 0
            legPivotLeft.eulerAngles.x = legSwing
            legPivotRight.eulerAngles.x = -legSwing

            // Torso/arm/head idle & walk pose — skipped entirely while the
            // chop ensemble (or its rest-ease) is still animating, so it
            // can't fight those nodes for control mid-swing.
            if armPivot.action(forKey: PlayerNodeFactory.chopSwingKey) == nil {
                if walking {
                    // Torso: a double-bounce vertical dip (once per
                    // footfall, not once per stride) plus a subtle twist
                    // and forward lean, so the upper body reads as
                    // "walking with purpose" rather than just the legs.
                    body.position.y = Float(sin(2 * walkPhase)) * 0.5
                    body.eulerAngles.y = Float(sin(walkPhase)) * 0.06
                    body.eulerAngles.x = SceneKitConversions.radians(fromDegrees: -3.4)

                    // Arms swing opposite phase to the leg on the same
                    // side (contralateral gait), at a lower amplitude than
                    // the legs, with a synced elbow flex that bends more
                    // at the back of each swing.
                    let armSwing = legSwing * 0.7
                    let elbowFlex = max(0, Float(sin(walkPhase))) * 20
                    let elbowFlexLeft = max(0, Float(sin(walkPhase + .pi))) * 20
                    armPivot.eulerAngles.x = SceneKitConversions.radians(fromDegrees: Double(PlayerNodeFactory.RestPose.shoulderX)) - armSwing
                    armPivot.eulerAngles.z = SceneKitConversions.radians(fromDegrees: Double(PlayerNodeFactory.RestPose.shoulderZ))
                    forearmPivot.eulerAngles.x = SceneKitConversions.radians(fromDegrees: Double(PlayerNodeFactory.RestPose.elbowX)) + SceneKitConversions.radians(fromDegrees: Double(elbowFlex))
                    armPivotLeft.eulerAngles.x = SceneKitConversions.radians(fromDegrees: Double(PlayerNodeFactory.RestPose.shoulderLeftX)) + armSwing
                    forearmPivotLeft.eulerAngles.x = SceneKitConversions.radians(fromDegrees: Double(PlayerNodeFactory.RestPose.elbowLeftX)) + SceneKitConversions.radians(fromDegrees: Double(elbowFlexLeft))
                    head.eulerAngles.z = 0
                } else {
                    // Idle: a slow, low-amplitude breathing sway so the
                    // character isn't a static mannequin while standing
                    // still — a gentle chest rise and faint head sway,
                    // clearly slower/subtler than the walk cycle.
                    let idlePhase = CACurrentMediaTime() * 1.1
                    let chestRise = Float(sin(idlePhase)) * 0.03
                    body.position.y = Float(sin(idlePhase)) * 0.5
                    body.eulerAngles.x = 0
                    body.eulerAngles.y = 0
                    armPivot.eulerAngles.x = SceneKitConversions.radians(fromDegrees: Double(PlayerNodeFactory.RestPose.shoulderX)) + chestRise
                    armPivot.eulerAngles.z = SceneKitConversions.radians(fromDegrees: Double(PlayerNodeFactory.RestPose.shoulderZ))
                    forearmPivot.eulerAngles.x = SceneKitConversions.radians(fromDegrees: Double(PlayerNodeFactory.RestPose.elbowX))
                    armPivotLeft.eulerAngles.x = SceneKitConversions.radians(fromDegrees: Double(PlayerNodeFactory.RestPose.shoulderLeftX)) + chestRise
                    forearmPivotLeft.eulerAngles.x = SceneKitConversions.radians(fromDegrees: Double(PlayerNodeFactory.RestPose.elbowLeftX))
                    head.eulerAngles.z = Float(sin(idlePhase * 0.5)) * 0.02
                }
            }
        }

        /// Spawns a wood-chip burst and a brief recoil wobble on the
        /// struck tree, called only on successful chop-tick attempts
        /// (misses still swing the axe, just produce no feedback).
        private func playChopImpact(event: ChopStrikeEvent, game: GameState) {
            guard let treeNode = treeNodes[event.treeKey] else { return }
            let species = game.worldTrees.first(where: { $0.key == event.treeKey })?.species ?? .oak
            let impactPoint = SceneKitConversions.vector(event.worldPosition, height: 20)
            let seed = UInt64(bitPattern: Int64(event.id.hashValue))

            let burst = ImpactEffects.woodChipBurst(at: impactPoint, species: species, seed: seed)
            scene.rootNode.addChildNode(burst)
            treeNode.runAction(ImpactEffects.treeShake(seed: seed), forKey: "impactShake")
        }

        private func setUpLights() {
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = SceneKitConversions.uiColor(TimberlineTheme.Scene3D.ambient)
            ambient.intensity = 500
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            let directional = SCNLight()
            directional.type = .directional
            directional.color = SceneKitConversions.uiColor(TimberlineTheme.Scene3D.sunlight)
            directional.intensity = 1000
            directional.castsShadow = true
            // .forward avoids the full G-buffer allocation required by .deferred,
            // saving ~50–100 MB of render-target memory on startup. Shadow color
            // is set as UIColor directly, which is the correct API for forward mode.
            directional.shadowMode = .forward
            directional.shadowColor = UIColor.black.withAlphaComponent(0.30)
            // 4 samples give soft shadow edges at a fraction of the GPU
            // cost of the previous 16-sample PCF kernel, which — combined
            // with the broken camera frustum below — was the main
            // per-frame GPU expense contributing to startup instability.
            directional.shadowRadius = 4
            directional.shadowSampleCount = 4
            directional.shadowMapSize = CGSize(width: 1024, height: 1024)
            let directionalNode = SCNNode()
            directionalNode.light = directional
            // Pitch lowered from -60° to -36° alongside the camera's move
            // from ~54° to 30° elevation, keeping the sun's angle relative
            // to the new shallower camera consistent with before.
            directionalNode.eulerAngles = SCNVector3(
                -Float.pi / 5, Float.pi / 4, 0
            )
            scene.rootNode.addChildNode(directionalNode)
        }

        /// Distance haze: geometry fades into `Scene3D.haze` well inside
        /// the tree despawn boundary, hiding pop-in at the top of the
        /// screen and giving the tilt-shift diorama read. Camera-to-target
        /// distance is ~1110, so near-field stays completely clean.
        private func setUpAtmosphere() {
            scene.fogColor = SceneKitConversions.uiColor(TimberlineTheme.Scene3D.haze)
            scene.fogStartDistance = 1500
            scene.fogEndDistance = 2300
            scene.fogDensityExponent = 2
        }

        /// Camera sits at (0, 555, 961) → ~1110 units from its look-at
        /// target with a 30° elevation (down from the previous 54°), so
        /// ground-depth visibility (which scales with `1/sin(elevation)`)
        /// would roughly double at the old scale of 350. Re-tuned to 216
        /// (`350 * sin(30°)/sin(54°)`) to keep the same ~860-world-unit
        /// visible ground depth as before the tilt change — appropriate
        /// for an explore/gather loop. Because vertical objects foreshorten
        /// by `cos(elevation)`, the shallower angle now shows the
        /// 58-unit-tall player at ~23% of screen height (vs ~10% before),
        /// which is the intended effect of tilting away from top-down.
        /// The previous value of 8 (a ~16-unit visible window) clipped the
        /// player's head and fed SceneKit an incorrect frustum for shadow
        /// cascade calculations, contributing to startup instability.
        /// Divided by `Camera.zoomScale` each frame in `updateCamera` to
        /// implement pinch-to-zoom.
        static let baseOrthographicScale: Double = 216

        private func setUpCamera() {
            let camera = SCNCamera()
            camera.usesOrthographicProjection = true
            camera.orthographicScale = Self.baseOrthographicScale
            camera.zNear = 1
            camera.zFar = 5000
            cameraNode.camera = camera
            scene.rootNode.addChildNode(cameraNode)
        }

        /// Updates the streamed ground tile grid around the player's current
        /// chunk. Tiles are loaded lazily for nearby chunks and removed once
        /// they fall outside the configured `GameData.chunkLoadRadius`.
        func updateGround(playerPosition: CGPoint) {
            groundStreamer.update(playerPosition: playerPosition)
        }

        /// Points the camera at `game.camera.center` — already lerp-smoothed
        /// by `Camera.follow` — each call. Deliberately does not re-lerp here,
        /// which would double-smooth and lag behind the player.
        func updateCamera(game: GameState) {
            let target = SceneKitConversions.vector(game.camera.center)
            cameraNode.position = SCNVector3(
                target.x + Self.cameraOffset.x,
                target.y + Self.cameraOffset.y,
                target.z + Self.cameraOffset.z
            )
            cameraNode.look(at: target)
            cameraNode.camera?.orthographicScale = Self.baseOrthographicScale / Double(game.camera.zoomScale)
        }
    }
}
