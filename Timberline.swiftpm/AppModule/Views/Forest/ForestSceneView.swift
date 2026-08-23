import SpriteKit
import SwiftUI
import UIKit

/// A SpriteKit-backed 2D forest scene. All world objects — ground tiles,
/// trees, and the player — are drawn as `SKSpriteNode`s whose `zPosition`
/// is set to their world-space Y coordinate every frame. Because SpriteKit
/// renders higher `zPosition` values on top, objects that sit lower on the
/// screen (higher world Y = "closer" to the camera) naturally occlude
/// objects that are higher up, giving a convincing illusion of depth
/// without any 3D geometry.
struct ForestSceneView: UIViewRepresentable {
    @EnvironmentObject private var game: GameState
    @ObservedObject var hudBridge: SceneHUDBridge

    /// World units visible vertically at zoom level 1.0. Matches the
    /// comment in `Camera.swift` ("~350-unit-tall view at zoom 1").
    static let baseVisibleWorldHeight: CGFloat = 350

    func makeUIView(context: Context) -> SKView {
        let skView = SKView(frame: .zero)
        // zPosition on each node controls ordering; sibling order doesn't.
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false

        let scene = SKScene()
        scene.scaleMode = .resizeFill
        scene.backgroundColor = UIColor(TimberlineTheme.SceneArt.haze)
        // (0,0) at the scene centre makes camera positioning simple.
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        let cam = SKCameraNode()
        scene.addChild(cam)
        scene.camera = cam

        context.coordinator.scene = scene
        context.coordinator.cameraNode = cam
        skView.presentScene(scene)
        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        context.coordinator.update(game: game)
        hudBridge.update(game: game, viewSize: uiView.bounds.size)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator {
        var scene: SKScene?
        var cameraNode: SKCameraNode?
        var playerNode: SKNode?
        var treeNodes: [String: SKNode] = [:]
        var groundTiles: [ChunkCoord: SKSpriteNode] = [:]
        var lastChopStrikeID: UUID?
        var animationController = SkillerAnimationController()
        private let playerDepthBias: CGFloat = 0.001

        func update(game: GameState) {
            guard let scene else { return }

            // ── Camera ────────────────────────────────────────────────────
            if let cam = cameraNode {
                let zoom = game.camera.zoomScale
                // SKCameraNode scale: smaller = more zoomed in.
                cam.setScale(1.0 / zoom)
                // Game Y increases downward; SpriteKit Y increases upward,
                // so we negate the Y component when placing all nodes.
                cam.position = CGPoint(
                    x: game.camera.center.x,
                    y: -game.camera.center.y
                )
            }

            // ── Player ────────────────────────────────────────────────────
            if playerNode == nil {
                let node = makePlayerNode()
                scene.addChild(node)
                playerNode = node
            }
            if let node = playerNode {
                let p = game.player.position
                node.position = CGPoint(x: p.x, y: -p.y)
                // Sort by the character's feet so its whole silhouette is
                // behind a tree when its feet are behind the tree's base.
                node.zPosition = depthZ(forWorldY: p.y, bias: playerDepthBias)

                // Mirror sprite horizontally when walking left/right.
                if let body = node.childNode(withName: "body") as? SKSpriteNode {
                    if game.player.velocity.x > 1 {
                        body.xScale = abs(body.xScale)
                    } else if game.player.velocity.x < -1 {
                        body.xScale = -abs(body.xScale)
                    }
                }

                // Drive animation state.
                switch game.player.animation {
                case .walking:
                    animationController.setMovement(isMoving: true)
                case .chopping, .idle:
                    animationController.setMovement(isMoving: false)
                }
            }

            // ── Chop-strike feedback ──────────────────────────────────────
            if let chopStrike = game.lastChopStrike,
               chopStrike.id != lastChopStrikeID
            {
                lastChopStrikeID = chopStrike.id
                animationController.playChop()
                if let node = playerNode {
                    playChopShake(on: node)
                }
            }

            // ── Trees ─────────────────────────────────────────────────────
            let renderRadius = GameData.treeRenderRadius
            let keepRadius = renderRadius + GameData.treeRenderHysteresis
            let playerPos = game.player.position

            let visibleTrees = game.worldTrees.filter { tree in
                let dx = tree.worldPosition.x - playerPos.x
                let dy = tree.worldPosition.y - playerPos.y
                let dist = hypot(dx, dy)
                // Keep existing nodes slightly beyond the render radius to
                // reduce spawn/despawn churn at the boundary.
                return treeNodes[tree.key] != nil ? dist <= keepRadius : dist <= renderRadius
            }

            var seenKeys = Set<String>()
            for tree in visibleTrees.prefix(220) {
                seenKeys.insert(tree.key)
                let isFelled = tree.logsRemaining <= 0 || tree.isDepleted
                let p = tree.worldPosition

                if let existing = treeNodes[tree.key] {
                    // Swap the node if the tree was just felled (or
                    // unexpectedly respawned).
                    let isStump = existing.name == "stump"
                    if isStump != isFelled {
                        existing.removeFromParent()
                        treeNodes.removeValue(forKey: tree.key)
                    } else {
                        existing.position = CGPoint(x: p.x, y: -p.y)
                        existing.zPosition = depthZ(forWorldY: p.y)
                        continue
                    }
                }

                let node = makeTreeNode(species: tree.species, isFelled: isFelled)
                node.position = CGPoint(x: p.x, y: -p.y)
                node.zPosition = depthZ(forWorldY: p.y)
                scene.addChild(node)
                treeNodes[tree.key] = node
            }

            // Remove nodes for trees that have scrolled out of range.
            for key in treeNodes.keys where !seenKeys.contains(key) {
                treeNodes[key]?.removeFromParent()
                treeNodes.removeValue(forKey: key)
            }

            // ── Ground tiles ──────────────────────────────────────────────
            let desiredCoords = ChunkManager.loadedChunkSet(around: game.player.position)
            for coord in desiredCoords where groundTiles[coord] == nil {
                let tile = makeGroundTile(coord: coord)
                scene.addChild(tile)
                groundTiles[coord] = tile
            }
            for coord in groundTiles.keys where !desiredCoords.contains(coord) {
                groundTiles[coord]?.removeFromParent()
                groundTiles.removeValue(forKey: coord)
            }
        }

        // MARK: Node factories

        private func depthZ(forWorldY worldY: CGFloat, bias: CGFloat = 0) -> CGFloat {
            worldY + bias
        }

        private func makePlayerNode() -> SKNode {
            let root = SKNode()
            root.name = "player"

            // Bare calves and chunky shoes, matching the chibi woodcutter model.
            for (xOffset, legName) in [(-5, "legL"), (5, "legR")] as [(Int, String)] {
                let leg = SKSpriteNode(
                    color: UIColor(TimberlineTheme.SceneArt.skin),
                    size: CGSize(width: 7, height: 12)
                )
                leg.name = legName
                leg.position = CGPoint(x: xOffset, y: 10)
                root.addChild(leg)

                let shoe = SKSpriteNode(
                    color: UIColor(TimberlineTheme.SceneArt.shoes),
                    size: CGSize(width: 9, height: 5)
                )
                shoe.name = legName == "legL" ? "shoeL" : "shoeR"
                shoe.position = CGPoint(x: xOffset, y: 2)
                root.addChild(shoe)
            }

            // Blue shorts
            let shorts = SKSpriteNode(
                color: UIColor(TimberlineTheme.SceneArt.shorts),
                size: CGSize(width: 17, height: 8)
            )
            shorts.position = CGPoint(x: 0, y: 19)
            root.addChild(shorts)

            // Vest over the light shirt
            let body = SKSpriteNode(
                color: UIColor(TimberlineTheme.SceneArt.vest),
                size: CGSize(width: 18, height: 20)
            )
            body.name = "body"
            body.position = CGPoint(x: 0, y: 24)
            root.addChild(body)

            let collar = SKSpriteNode(
                color: UIColor(TimberlineTheme.SceneArt.shirt),
                size: CGSize(width: 19, height: 3)
            )
            collar.position = CGPoint(x: 0, y: 36)
            root.addChild(collar)

            // Shirt sleeves and exposed forearms.
            for xOffset in [-11, 11] {
                let sleeve = SKSpriteNode(
                    color: UIColor(TimberlineTheme.SceneArt.shirt),
                    size: CGSize(width: 6, height: 10)
                )
                sleeve.name = xOffset < 0 ? "sleeveL" : "sleeveR"
                sleeve.position = CGPoint(x: xOffset, y: 32)
                root.addChild(sleeve)

                let forearm = SKSpriteNode(
                    color: UIColor(TimberlineTheme.SceneArt.skin),
                    size: CGSize(width: 5, height: 9)
                )
                forearm.name = xOffset < 0 ? "forearmL" : "forearmR"
                forearm.position = CGPoint(x: xOffset, y: 24)
                root.addChild(forearm)
            }

            // Axe held at the right side.
            let axeHandle = SKSpriteNode(
                color: UIColor(TimberlineTheme.barkLight),
                size: CGSize(width: 3, height: 20)
            )
            // Hold the axe at the same slight diagonal as the 3D model.
            let axeTiltDegrees: CGFloat = -14.3
            let axeTiltRadians = axeTiltDegrees * CGFloat.pi / 180
            axeHandle.zRotation = axeTiltRadians
            axeHandle.position = CGPoint(x: 14, y: 20)
            root.addChild(axeHandle)

            let axeMetal = AxeArt.metalColors(for: .bronze)
            let axeHead = SKSpriteNode(
                color: UIColor(axeMetal.light),
                size: CGSize(width: 10, height: 7)
            )
            axeHead.position = CGPoint(x: 2, y: 9)
            axeHandle.addChild(axeHead)

            let axeBladeEdge = SKSpriteNode(
                color: UIColor(axeMetal.dark),
                size: CGSize(width: 10, height: 2)
            )
            axeBladeEdge.position = CGPoint(x: 2, y: 6.5)
            axeHandle.addChild(axeBladeEdge)

            // Head
            let head = SKShapeNode(circleOfRadius: 9.5)
            head.name = "head"
            head.fillColor = UIColor(TimberlineTheme.SceneArt.skin)
            head.strokeColor = .clear
            head.position = CGPoint(x: 0, y: 46)
            root.addChild(head)

            // Straw hat — brim
            let brim = SKSpriteNode(
                color: UIColor(TimberlineTheme.SceneArt.hatStraw),
                size: CGSize(width: 26, height: 3)
            )
            brim.position = CGPoint(x: 0, y: 52)
            root.addChild(brim)

            let band = SKSpriteNode(
                color: UIColor(TimberlineTheme.SceneArt.hatBand),
                size: CGSize(width: 15, height: 2)
            )
            band.position = CGPoint(x: 0, y: 56)
            root.addChild(band)

            // Straw hat — crown
            let crown = SKShapeNode(circleOfRadius: 7)
            crown.fillColor = UIColor(TimberlineTheme.SceneArt.hatStraw)
            crown.strokeColor = .clear
            crown.position = CGPoint(x: 0, y: 57)
            root.addChild(crown)

            return root
        }

        private func makeTreeNode(species: TreeSpecies, isFelled: Bool) -> SKNode {
            let root = SKNode()
            root.name = isFelled ? "stump" : "tree"

            if isFelled {
                // Draw a flat ellipse for the stump top.
                let stump = SKShapeNode(ellipseOf: CGSize(width: 14, height: 8))
                stump.fillColor = UIColor(TimberlineTheme.SceneArt.trunk)
                stump.strokeColor = UIColor(TimberlineTheme.SceneArt.trunkDark)
                stump.lineWidth = 1.5
                root.addChild(stump)
                return root
            }

            let trunkColor = TimberlineTheme.SceneArt.trunkColor(for: species)
            let trunkHeight: CGFloat = 30

            // Trunk rectangle — its base sits at the node origin (which is
            // used as the Y-sort anchor), so the sprite is offset upward.
            let trunk = SKSpriteNode(
                color: UIColor(trunkColor),
                size: CGSize(width: 10, height: trunkHeight)
            )
            trunk.position = CGPoint(x: 0, y: trunkHeight / 2)
            root.addChild(trunk)

            // Canopy — try the bundled PNG leaf sprites first; fall back to
            // a plain coloured circle if the texture is unavailable.
            let (baseColor, _) = TimberlineTheme.SceneArt.canopy(for: species)
            let radius = canopyRadius(for: species)
            let tier = canopyTier(for: species)
            let canopyY = trunkHeight + radius * 0.7

            if let tex = loadTexture(named: "Leaf_Tier\(tier)", subdirectory: "LeafSprites") {
                let diameter = radius * 2
                let canopy = SKSpriteNode(texture: tex, size: CGSize(width: diameter, height: diameter))
                canopy.colorBlendFactor = 0.4
                canopy.color = UIColor(baseColor)
                canopy.position = CGPoint(x: 0, y: canopyY)
                root.addChild(canopy)
            } else {
                let canopy = SKShapeNode(circleOfRadius: radius)
                canopy.fillColor = UIColor(baseColor)
                canopy.strokeColor = .clear
                canopy.position = CGPoint(x: 0, y: canopyY)
                root.addChild(canopy)
            }

            return root
        }

        private func makeGroundTile(coord: ChunkCoord) -> SKSpriteNode {
            let size = CGFloat(GameData.chunkSize)
            let worldX = CGFloat(coord.x) * size + size / 2
            let worldY = CGFloat(coord.y) * size + size / 2

            let tile: SKSpriteNode
            if let tex = loadTexture(named: "Grass_Tileable", subdirectory: "Environment/Ground") {
                tile = SKSpriteNode(texture: tex, size: CGSize(width: size, height: size))
            } else {
                tile = SKSpriteNode(
                    color: UIColor(TimberlineTheme.SceneArt.grass),
                    size: CGSize(width: size, height: size)
                )
            }

            tile.position = CGPoint(x: worldX, y: -worldY)
            // Ground tiles always render beneath every other sprite.
            tile.zPosition = -10_000
            tile.name = "groundTile"
            return tile
        }

        // MARK: Animations

        private func playChopShake(on node: SKNode) {
            let shake = SKAction.sequence([
                SKAction.moveBy(x: 3, y: 0, duration: 0.05),
                SKAction.moveBy(x: -6, y: 0, duration: 0.05),
                SKAction.moveBy(x: 3, y: 0, duration: 0.05),
            ])
            node.run(shake)
        }

        // MARK: Texture cache

        private static var textureCache: [String: SKTexture] = [:]

        private func loadTexture(named name: String, subdirectory: String) -> SKTexture? {
            let key = "\(subdirectory)/\(name)"
            if let cached = Self.textureCache[key] { return cached }
            guard let url = Bundle.module.url(
                forResource: name, withExtension: "png", subdirectory: subdirectory
            ),
                let uiImage = UIImage(contentsOfFile: url.path)
            else { return nil }
            let texture = SKTexture(image: uiImage)
            Self.textureCache[key] = texture
            return texture
        }

        // MARK: Per-species helpers

        private func canopyRadius(for species: TreeSpecies) -> CGFloat {
            switch species {
            case .birch:     return 32
            case .oak:       return 40
            case .willow:    return 38
            case .evergreen: return 30
            case .ancientYew:return 44
            case .elderwood: return 50
            }
        }

        private func canopyTier(for species: TreeSpecies) -> Int {
            switch species {
            case .birch:     return 1
            case .oak:       return 2
            case .willow:    return 3
            case .evergreen: return 4
            case .ancientYew:return 4
            case .elderwood: return 5
            }
        }
    }
}
