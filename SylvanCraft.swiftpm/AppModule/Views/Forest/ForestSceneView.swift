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
        scnView.backgroundColor = SceneKitConversions.uiColor(SylvanTheme.skyBottom)
        scnView.rendersContinuously = true
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

        init() {
            setUpLights()
            setUpGround()
            setUpCamera()
            treeContainer.name = "trees"
            scene.rootNode.addChildNode(treeContainer)
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

            let node = tree.isDepleted
                ? TreeGeometryFactory.makeStumpNode(species: tree.species)
                : TreeGeometryFactory.makeTreeNode(species: tree.species, locked: locked)
            node.name = desiredName
            node.position = SceneKitConversions.vector(tree.worldPosition)
            treeContainer.addChildNode(node)
            treeNodes[tree.key] = node
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
            body.position.y = game.player.animation == .walking
                ? Float(sin(CACurrentMediaTime() * 8) * 2)
                : 0

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
            ambient.color = SceneKitConversions.uiColor(SylvanTheme.skyTop)
            ambient.intensity = 400
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            let directional = SCNLight()
            directional.type = .directional
            directional.color = SceneKitConversions.uiColor(.white)
            directional.intensity = 900
            directional.castsShadow = true
            directional.shadowMode = .deferred
            directional.shadowColor = SceneKitConversions.uiColor(Color.black.opacity(0.35))
            let directionalNode = SCNNode()
            directionalNode.light = directional
            directionalNode.eulerAngles = SCNVector3(
                -Float.pi / 3, Float.pi / 4, 0
            )
            scene.rootNode.addChildNode(directionalNode)
        }

        private func setUpGround() {
            let plane = SCNPlane(width: 4000, height: 4000)
            let material = SCNMaterial()
            material.diffuse.contents = SceneKitConversions.uiColor(SylvanTheme.groundLight)
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
            camera.orthographicScale = 8
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
