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
        // Break equal-foot-position ties in favour of the player.
        private let playerDepthBias: CGFloat = 0.001
        private let playerLayerScale: CGFloat = 0.00001

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
                node.zPosition = p.y + playerDepthBias

                // Mirror the complete silhouette, including the face, hair, and axe,
                // when walking left/right.
                if game.player.velocity.x > 1 {
                    node.xScale = abs(node.xScale)
                } else if game.player.velocity.x < -1 {
                    node.xScale = -abs(node.xScale)
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
                        existing.zPosition = p.y
                        continue
                    }
                }

                let node = makeTreeNode(species: tree.species, isFelled: isFelled)
                node.position = CGPoint(x: p.x, y: -p.y)
                node.zPosition = p.y
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

        private func makePlayerNode() -> SKNode {
            let root = SKNode()
            root.name = "player"

            let skin = UIColor(TimberlineTheme.SceneArt.skin)
            let skinShadow = UIColor(TimberlineTheme.SceneArt.skinShadow)
            let hair = UIColor(TimberlineTheme.SceneArt.hair)
            let hairShadow = UIColor(TimberlineTheme.SceneArt.hairShadow)
            let scarf = UIColor(TimberlineTheme.SceneArt.scarf)
            let scarfShadow = UIColor(TimberlineTheme.SceneArt.scarfShadow)
            let shirt = UIColor(TimberlineTheme.SceneArt.shirt)
            let shirtShadow = UIColor(TimberlineTheme.SceneArt.shirtShadow)
            let leather = UIColor(TimberlineTheme.SceneArt.leather)
            let leatherHighlight = UIColor(TimberlineTheme.SceneArt.leatherHighlight)
            let pants = UIColor(TimberlineTheme.SceneArt.pants)
            let boots = UIColor(TimberlineTheme.SceneArt.boots)
            let bootTrim = UIColor(TimberlineTheme.SceneArt.bootTrim)
            let belt = UIColor(TimberlineTheme.SceneArt.belt)

            // Backpack and rear leg sit behind the rest of the silhouette.
            let pack = SKShapeNode(ellipseOf: CGSize(width: 13, height: 20))
            pack.fillColor = leather
            pack.strokeColor = leatherHighlight
            pack.lineWidth = 1.5
            pack.position = CGPoint(x: -12, y: 53)
            pack.zPosition = -3
            root.addChild(pack)

            let packCap = SKShapeNode(ellipseOf: CGSize(width: 9, height: 11))
            packCap.fillColor = leatherHighlight
            packCap.strokeColor = leather
            packCap.lineWidth = 1
            packCap.position = CGPoint(x: -14, y: 60)
            packCap.zPosition = -2
            root.addChild(packCap)

            // Brown trousers and tall red leather boots.
            for (xOffset, legName) in [(-5, "legL"), (5, "legR")] as [(CGFloat, String)] {
                let trouser = SKSpriteNode(color: pants, size: CGSize(width: 9, height: 24))
                trouser.name = legName
                trouser.position = CGPoint(x: xOffset, y: 28)
                trouser.zPosition = -1
                root.addChild(trouser)

                let boot = SKSpriteNode(color: boots, size: CGSize(width: 10, height: 16))
                boot.name = legName == "legL" ? "bootL" : "bootR"
                boot.position = CGPoint(x: xOffset, y: 11)
                boot.zPosition = 1
                root.addChild(boot)

                let cuff = SKSpriteNode(color: bootTrim, size: CGSize(width: 11, height: 4))
                cuff.position = CGPoint(x: xOffset, y: 18)
                cuff.zPosition = 2
                root.addChild(cuff)

                let foot = polygonNode(
                    points: [
                        CGPoint(x: xOffset - 6, y: 6),
                        CGPoint(x: xOffset + 6, y: 6),
                        CGPoint(x: xOffset + 8, y: 3),
                        CGPoint(x: xOffset + 6, y: 1),
                        CGPoint(x: xOffset - 7, y: 1),
                    ],
                    color: boots
                )
                foot.zPosition = 2
                root.addChild(foot)

                let strap = SKSpriteNode(color: bootTrim, size: CGSize(width: 4, height: 7))
                strap.position = CGPoint(x: xOffset + 4, y: 10)
                strap.zRotation = -0.35
                strap.zPosition = 3
                root.addChild(strap)
            }

            let waistPanel = SKSpriteNode(color: pants, size: CGSize(width: 20, height: 10))
            waistPanel.name = "waist"
            waistPanel.position = CGPoint(x: 0, y: 40)
            waistPanel.zPosition = 0
            root.addChild(waistPanel)

            // Blue shirt with a warm leather tunic over the front.
            let body = SKSpriteNode(color: shirt, size: CGSize(width: 20, height: 24))
            body.name = "body"
            body.position = CGPoint(x: 0, y: 52)
            body.zPosition = 0
            root.addChild(body)

            let shirtFacet = polygonNode(
                points: [
                    CGPoint(x: -9, y: 41),
                    CGPoint(x: 2, y: 41),
                    CGPoint(x: 8, y: 63),
                    CGPoint(x: -7, y: 64),
                ],
                color: shirtShadow
            )
            shirtFacet.zPosition = 1
            root.addChild(shirtFacet)

            let tunic = polygonNode(
                points: [
                    CGPoint(x: -6, y: 42),
                    CGPoint(x: 7, y: 43),
                    CGPoint(x: 9, y: 61),
                    CGPoint(x: 4, y: 66),
                    CGPoint(x: -5, y: 63),
                ],
                color: leather
            )
            tunic.name = "leatherTunic"
            tunic.zPosition = 2
            root.addChild(tunic)

            let tunicFacet = polygonNode(
                points: [
                    CGPoint(x: 3, y: 43),
                    CGPoint(x: 7, y: 43),
                    CGPoint(x: 9, y: 61),
                    CGPoint(x: 4, y: 66),
                ],
                color: leatherHighlight
            )
            tunicFacet.zPosition = 3
            root.addChild(tunicFacet)

            let beltBand = SKSpriteNode(color: belt, size: CGSize(width: 21, height: 5))
            beltBand.position = CGPoint(x: 0, y: 41)
            beltBand.zPosition = 4
            root.addChild(beltBand)

            let beltBuckle = SKShapeNode(rectOf: CGSize(width: 4, height: 4), cornerRadius: 0.5)
            beltBuckle.fillColor = bootTrim
            beltBuckle.strokeColor = .clear
            beltBuckle.position = CGPoint(x: 4, y: 41)
            beltBuckle.zPosition = 5
            root.addChild(beltBuckle)

            // The blue short sleeves and wrapped forearms echo the reference's
            // layered adventurer outfit.
            let farSleeve = SKSpriteNode(color: shirtShadow, size: CGSize(width: 7, height: 13))
            farSleeve.position = CGPoint(x: -11, y: 56)
            farSleeve.zPosition = -1
            root.addChild(farSleeve)

            let farWrap = SKSpriteNode(color: leather, size: CGSize(width: 6, height: 10))
            farWrap.position = CGPoint(x: -12, y: 47)
            farWrap.zPosition = 0
            root.addChild(farWrap)

            let nearSleeve = SKSpriteNode(color: shirt, size: CGSize(width: 7, height: 14))
            nearSleeve.position = CGPoint(x: 11, y: 57)
            nearSleeve.zPosition = 5
            root.addChild(nearSleeve)

            let nearBracer = SKSpriteNode(color: UIColor(TimberlineTheme.SceneArt.bracer), size: CGSize(width: 7, height: 11))
            nearBracer.position = CGPoint(x: 12, y: 47)
            nearBracer.zPosition = 6
            root.addChild(nearBracer)

            let nearHand = SKShapeNode(ellipseOf: CGSize(width: 7, height: 8))
            nearHand.fillColor = skin
            nearHand.strokeColor = skinShadow
            nearHand.lineWidth = 1
            nearHand.position = CGPoint(x: 12, y: 42)
            nearHand.zPosition = 7
            root.addChild(nearHand)

            // Green scarf wraps the neck and trails over the shoulders.
            let scarfTail = polygonNode(
                points: [
                    CGPoint(x: -11, y: 62),
                    CGPoint(x: -3, y: 65),
                    CGPoint(x: -7, y: 49),
                    CGPoint(x: -14, y: 52),
                ],
                color: scarfShadow
            )
            scarfTail.zPosition = 4
            root.addChild(scarfTail)

            let scarfBand = polygonNode(
                points: [
                    CGPoint(x: -10, y: 65),
                    CGPoint(x: -5, y: 70),
                    CGPoint(x: 8, y: 67),
                    CGPoint(x: 12, y: 62),
                    CGPoint(x: 7, y: 59),
                    CGPoint(x: -7, y: 61),
                ],
                color: scarf
            )
            scarfBand.name = "scarf"
            scarfBand.zPosition = 8
            root.addChild(scarfBand)

            // Neck and side-profile face.
            let neck = SKSpriteNode(color: skin, size: CGSize(width: 7, height: 8))
            neck.position = CGPoint(x: 2, y: 68)
            neck.zPosition = 5
            root.addChild(neck)

            let hairBack = polygonNode(
                points: [
                    CGPoint(x: -10, y: 76),
                    CGPoint(x: -12, y: 82),
                    CGPoint(x: -9, y: 82),
                    CGPoint(x: -10, y: 87),
                    CGPoint(x: -5, y: 85),
                    CGPoint(x: -3, y: 93),
                    CGPoint(x: 1, y: 89),
                    CGPoint(x: 6, y: 92),
                    CGPoint(x: 7, y: 86),
                    CGPoint(x: 12, y: 88),
                    CGPoint(x: 9, y: 82),
                    CGPoint(x: 12, y: 79),
                    CGPoint(x: 5, y: 78),
                    CGPoint(x: 1, y: 74),
                    CGPoint(x: -5, y: 76),
                ],
                color: hairShadow
            )
            hairBack.zPosition = 4
            root.addChild(hairBack)

            let head = SKShapeNode(ellipseOf: CGSize(width: 17, height: 20))
            head.name = "head"
            head.fillColor = skin
            head.strokeColor = skinShadow
            head.lineWidth = 1
            head.position = CGPoint(x: 2, y: 79)
            head.zPosition = 5
            root.addChild(head)

            let faceShadow = polygonNode(
                points: [
                    CGPoint(x: 6, y: 87),
                    CGPoint(x: 11, y: 84),
                    CGPoint(x: 10, y: 76),
                    CGPoint(x: 5, y: 72),
                ],
                color: skinShadow
            )
            faceShadow.zPosition = 6
            root.addChild(faceShadow)

            let nose = polygonNode(
                points: [
                    CGPoint(x: 9, y: 82),
                    CGPoint(x: 14, y: 80),
                    CGPoint(x: 9, y: 78),
                ],
                color: skin
            )
            nose.zPosition = 7
            root.addChild(nose)

            let eye = SKShapeNode(circleOfRadius: 1)
            eye.fillColor = UIColor(TimberlineTheme.SceneArt.eye)
            eye.strokeColor = .clear
            eye.position = CGPoint(x: 7, y: 83)
            eye.zPosition = 8
            root.addChild(eye)

            let hairFront = polygonNode(
                points: [
                    CGPoint(x: -9, y: 81),
                    CGPoint(x: -8, y: 87),
                    CGPoint(x: -4, y: 85),
                    CGPoint(x: -3, y: 90),
                    CGPoint(x: 1, y: 87),
                    CGPoint(x: 4, y: 90),
                    CGPoint(x: 7, y: 86),
                    CGPoint(x: 6, y: 82),
                    CGPoint(x: 9, y: 81),
                    CGPoint(x: 5, y: 77),
                    CGPoint(x: 0, y: 79),
                    CGPoint(x: -4, y: 77),
                ],
                color: hair
            )
            hairFront.zPosition = 9
            root.addChild(hairFront)

            // Axe held forward at a low diagonal; flipping the root also flips
            // the tool when the player changes direction.
            let axeHandle = SKSpriteNode(color: UIColor(TimberlineTheme.barkLight), size: CGSize(width: 3, height: 31))
            let axeTiltDegrees: CGFloat = -70
            let axeTiltRadians = axeTiltDegrees * CGFloat.pi / 180
            axeHandle.zRotation = axeTiltRadians
            axeHandle.position = CGPoint(x: 24, y: 39)
            axeHandle.zPosition = 10
            root.addChild(axeHandle)

            let axeMetal = AxeArt.metalColors(for: .bronze)
            let axeHead = polygonNode(
                points: [
                    CGPoint(x: -1, y: 16),
                    CGPoint(x: 8, y: 15),
                    CGPoint(x: 11, y: 8),
                    CGPoint(x: 8, y: 3),
                    CGPoint(x: 1, y: 6),
                    CGPoint(x: -3, y: 11),
                ],
                color: UIColor(axeMetal.light)
            )
            axeHead.strokeColor = UIColor(axeMetal.dark)
            axeHead.lineWidth = 1
            axeHead.position = CGPoint(x: 0, y: 0)
            axeHead.zPosition = 1
            axeHandle.addChild(axeHead)

            let axeEdge = polygonNode(
                points: [
                    CGPoint(x: 8, y: 15),
                    CGPoint(x: 11, y: 8),
                    CGPoint(x: 8, y: 3),
                    CGPoint(x: 6, y: 7),
                ],
                color: UIColor(axeMetal.dark)
            )
            axeEdge.zPosition = 2
            axeHandle.addChild(axeEdge)

            // Keep the art's internal layers while letting the player's feet
            // remain the sole depth-sorting anchor against world objects.
            normalizePlayerLayers(in: root)
            return root
        }

        private func polygonNode(points: [CGPoint], color: UIColor) -> SKShapeNode {
            let path = CGMutablePath()
            guard let first = points.first else {
                assertionFailure("polygonNode requires at least one point")
                return SKShapeNode()
            }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()

            let node = SKShapeNode(path: path)
            node.fillColor = color
            node.strokeColor = .clear
            return node
        }

        private func normalizePlayerLayers(in node: SKNode) {
            for child in node.children {
                child.zPosition *= playerLayerScale
                normalizePlayerLayers(in: child)
            }
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
