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
        scnView.backgroundColor = SceneKitConversions.uiColor(SylvanTheme.Scene3D.haze)
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
        let groundNode = SCNNode()

        /// Fixed world-space offset of the camera from its look-at target,
        /// giving the isometric-style downward angled view.
        static let cameraOffset = SCNVector3(0, 900, 650)

        /// Grid interval the ground plane snaps to as the player moves, so a
        /// single fixed-size plane can cover a ~20,000-unit world without
        /// needing to grow indefinitely or track every sub-pixel of motion.
        static let groundSnapInterval: CGFloat = 2000

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

        /// Purely visual chunk decorations (rocks, dirt patches), one
        /// container node per loaded chunk, diffed at chunk granularity.
        private var decorationChunks: [ChunkCoord: SCNNode] = [:]
        /// A handful of shared decoration geometries reused across all
        /// instances (size differences come from node scale).
        private var decorationGeometryCache: [String: SCNGeometry] = [:]

        init() {
            setUpLights()
            setUpGround()
            setUpCamera()
            setUpAtmosphere()
            treeContainer.name = "trees"
            scene.rootNode.addChildNode(treeContainer)
            decorationContainer.name = "decorations"
            scene.rootNode.addChildNode(decorationContainer)
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
                    upsertTreeNode(for: tree, level: game.level)
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
                        baseColor: SylvanTheme.Scene3D.rock,
                        highlightColor: SylvanTheme.Scene3D.rockLight
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
                        color: light ? SylvanTheme.Scene3D.dirtLight : SylvanTheme.Scene3D.dirt
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
                        baseColor: SylvanTheme.Scene3D.pebble,
                        highlightColor: SylvanTheme.Scene3D.dirtLight
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

            guard let body = node.childNode(withName: PlayerNodeFactory.NodeName.body, recursively: true),
                  let armPivot = node.childNode(withName: PlayerNodeFactory.NodeName.armPivot, recursively: true)
            else { return }

            if lastAxeTier != game.equippedAxe {
                PlayerNodeFactory.rebuildAxe(in: armPivot, tier: game.equippedAxe)
                lastAxeTier = game.equippedAxe
            }

            body.scale = SCNVector3(game.player.facing == .left ? -1 : 1, 1, 1)
            let walking = game.player.animation == .walking
            body.position.y = walking
                ? Float(sin(CACurrentMediaTime() * 8))
                : 0

            // Hip-pivot leg swing; zeroing when idle doubles as the reset,
            // so no action bookkeeping is needed.
            let legSwing = walking ? Float(sin(CACurrentMediaTime() * 8)) * 0.5 : 0
            node.childNode(withName: PlayerNodeFactory.NodeName.legPivotLeft, recursively: true)?
                .eulerAngles.x = legSwing
            node.childNode(withName: PlayerNodeFactory.NodeName.legPivotRight, recursively: true)?
                .eulerAngles.x = -legSwing

            let isChopping = game.player.animation == .chopping
            let isSwinging = armPivot.action(forKey: PlayerNodeFactory.swingActionKey) != nil
            if isChopping, !isSwinging {
                armPivot.runAction(PlayerNodeFactory.swingAction(), forKey: PlayerNodeFactory.swingActionKey)
            } else if !isChopping, isSwinging {
                armPivot.removeAction(forKey: PlayerNodeFactory.swingActionKey)
                armPivot.runAction(PlayerNodeFactory.restAction())
            }
        }

        private func setUpLights() {
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = SceneKitConversions.uiColor(SylvanTheme.Scene3D.ambient)
            ambient.intensity = 500
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            let directional = SCNLight()
            directional.type = .directional
            directional.color = SceneKitConversions.uiColor(SylvanTheme.Scene3D.sunlight)
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
            directionalNode.eulerAngles = SCNVector3(
                -Float.pi / 3, Float.pi / 4, 0
            )
            scene.rootNode.addChildNode(directionalNode)
        }

        /// Distance haze: geometry fades into `Scene3D.haze` well inside
        /// the tree despawn boundary, hiding pop-in at the top of the
        /// screen and giving the tilt-shift diorama read. Camera-to-target
        /// distance is ~1110, so near-field stays completely clean.
        private func setUpAtmosphere() {
            scene.fogColor = SceneKitConversions.uiColor(SylvanTheme.Scene3D.haze)
            scene.fogStartDistance = 1500
            scene.fogEndDistance = 2300
            scene.fogDensityExponent = 2
        }

        private func setUpGround() {
            let plane = SCNPlane(width: 4000, height: 4000)
            let material = SCNMaterial()
            material.diffuse.contents = SceneKitConversions.uiColor(SylvanTheme.Scene3D.grass)
            material.lightingModel = .lambert
            material.isDoubleSided = true
            plane.materials = [material]

            groundNode.geometry = plane
            groundNode.name = "ground"
            groundNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            scene.rootNode.addChildNode(groundNode)
        }

        private func setUpCamera() {
            let camera = SCNCamera()
            camera.usesOrthographicProjection = true
            // Camera sits at (0, 900, 650) → ~1110 units from its look-at
            // target with a ~54° elevation, so the camera's "up" component
            // is ≈0.586 and the 58-unit-tall player maps to ~34 camera-
            // space units. A scale of 350 puts the player at ~10% of
            // screen height and reveals ~700 world units of ground —
            // appropriate for an explore/gather loop. The previous value
            // of 8 (a ~16-unit visible window) clipped the player's head
            // and fed SceneKit an incorrect frustum for shadow cascade
            // calculations, contributing to startup instability.
            camera.orthographicScale = 350
            camera.zNear = 1
            camera.zFar = 5000
            cameraNode.camera = camera
            scene.rootNode.addChildNode(cameraNode)
        }

        /// Coarse-snaps the ground plane toward the player so the fixed
        /// 4000×4000 plane always covers the visible area, without
        /// repositioning (and re-triggering shadow recalculation) every
        /// single frame of movement.
        func updateGround(playerPosition: CGPoint) {
            let interval = Self.groundSnapInterval
            let snappedX = (playerPosition.x / interval).rounded() * interval
            let snappedY = (playerPosition.y / interval).rounded() * interval
            groundNode.position = SceneKitConversions.vector(CGPoint(x: snappedX, y: snappedY))
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
        }
    }
}
