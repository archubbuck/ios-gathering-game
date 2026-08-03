import ARKit
import RealityKit
import SwiftUI
import UIKit

/// A lightweight RealityKit viewport for the forest scene. The current pass
/// swaps the temporary placeholder cubes for the bundled USDZ assets from the
/// app resources, while keeping the player/camera/world updates intact.
struct ForestSceneView: UIViewRepresentable {
    @EnvironmentObject private var game: GameState
    @ObservedObject var hudBridge: SceneHUDBridge

    private enum VisualScale {
        static let playerHeight: Float = 58
        static let stumpHeight: Float = 18
    }

    @MainActor
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.environment.background = .color(UIColor(TimberlineTheme.Scene3D.haze))
        arView.cameraMode = .nonAR
        arView.automaticallyConfigureSession = false

        let anchor = AnchorEntity(world: .zero)
        let ground = makeGroundEntity()
        anchor.addChild(ground)

        let player = makePlayerEntity()
        anchor.addChild(player)

        let animationController = SkillerAnimationController(rootEntity: player)

        let camera = PerspectiveCamera()
        anchor.addChild(camera)

        context.coordinator.arView = arView
        context.coordinator.anchor = anchor
        context.coordinator.playerEntity = player
        context.coordinator.groundEntity = ground
        context.coordinator.animationController = animationController
        context.coordinator.cameraEntity = camera

        arView.scene.anchors.append(anchor)
        return arView
    }

    @MainActor
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.update(game: game)
        hudBridge.update(game: game, arView: uiView)
    }

    @MainActor
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var arView: ARView?
        var anchor: AnchorEntity?
        var playerEntity: Entity?
        var groundEntity: ModelEntity?
        var animationController: SkillerAnimationController?
        var cameraEntity: PerspectiveCamera?
        var treeEntities: [String: Entity] = [:]
        var groundTiles: [ChunkCoord: ModelEntity] = [:]
        var lastChopStrikeID: UUID?

        @MainActor
        func update(game: GameState) {
            guard let anchor else { return }

            if let playerEntity {
                playerEntity.position = SIMD3<Float>(
                    Float(game.player.position.x),
                    0.0,
                    Float(game.player.position.y)
                )
                playerEntity.transform.rotation = simd_quatf(
                    angle: Float(game.player.facingAngle),
                    axis: SIMD3<Float>(0, 1, 0)
                )
            }

            if let chopStrike = game.lastChopStrike, chopStrike.id != lastChopStrikeID {
                lastChopStrikeID = chopStrike.id
                animationController?.playChop()
                if chopStrike.success, let treeEntity = treeEntities[chopStrike.treeKey] {
                    treeEntity.position = SIMD3<Float>(
                        treeEntity.position.x,
                        0.0,
                        treeEntity.position.z
                    )
                }
            }

            switch game.player.animation {
            case .walking:
                animationController?.setMovement(isMoving: true, isRunning: false)
            case .chopping:
                break
            case .idle:
                animationController?.setMovement(isMoving: false, isRunning: false)
            }

            if let cameraEntity {
                let target = SIMD3<Float>(
                    Float(game.player.position.x),
                    0,
                    Float(game.player.position.y)
                )
                let cameraPosition = SIMD3<Float>(target.x, 8, target.z + 10)
                let cameraRotation = simd_quatf(angle: -.pi / 4, axis: SIMD3<Float>(1, 0, 0))
                cameraEntity.transform = Transform(
                    scale: SIMD3<Float>(repeating: 1),
                    rotation: cameraRotation,
                    translation: cameraPosition
                )
            }

            let renderRadius = GameData.treeRenderRadius
            let keepRadius = renderRadius + GameData.treeRenderHysteresis
            let playerPosition = game.player.position
            let visibleTrees = game.worldTrees.filter { tree in
                let dx = tree.worldPosition.x - playerPosition.x
                let dy = tree.worldPosition.y - playerPosition.y
                let distance = hypot(dx, dy)

                // Existing nodes are kept slightly longer to avoid
                // rapid spawn/despawn churn at the radius boundary.
                if treeEntities[tree.key] != nil {
                    return distance <= keepRadius
                }
                return distance <= renderRadius
            }
            var seenKeys = Set<String>()

            let maxRenderedTrees = 220
            for tree in visibleTrees.prefix(maxRenderedTrees) {
                seenKeys.insert(tree.key)

                let isFelled = tree.logsRemaining <= 0 || tree.isDepleted
                if let existing = treeEntities[tree.key] {
                    let shouldSwap = (existing.name == "tree" && isFelled) || (existing.name == "stump" && !isFelled)
                    if shouldSwap {
                        existing.removeFromParent()
                        treeEntities.removeValue(forKey: tree.key)
                    } else {
                        existing.position = SIMD3<Float>(
                            Float(tree.worldPosition.x),
                            0.0,
                            Float(tree.worldPosition.y)
                        )
                        continue
                    }
                }

                let entity = ForestSceneView.makeTreeEntity(species: tree.species, isFelled: isFelled)
                entity.position = SIMD3<Float>(
                    Float(tree.worldPosition.x),
                    0.0,
                    Float(tree.worldPosition.y)
                )
                anchor.addChild(entity)
                treeEntities[tree.key] = entity
            }

            let staleTreeKeys = treeEntities.keys.filter { !seenKeys.contains($0) }
            for key in staleTreeKeys {
                treeEntities[key]?.removeFromParent()
                treeEntities.removeValue(forKey: key)
            }

            let desiredGroundCoords = ChunkManager.loadedChunkSet(around: game.player.position)
            let currentGroundCoords = Set(groundTiles.keys)
            for coord in desiredGroundCoords where groundTiles[coord] == nil {
                let tile = GroundTileGenerator.makeTileEntity(coord: coord)
                anchor.addChild(tile)
                groundTiles[coord] = tile
            }
            for coord in currentGroundCoords where !desiredGroundCoords.contains(coord) {
                groundTiles[coord]?.removeFromParent()
                groundTiles.removeValue(forKey: coord)
            }
        }
    }

    private func makeGroundEntity() -> ModelEntity {
        let material = SimpleMaterial(
            color: UIColor(TimberlineTheme.Scene3D.dirt),
            roughness: 0.95,
            isMetallic: false
        )
        let mesh = MeshResource.generatePlane(width: 400, height: 400)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = SIMD3<Float>(0, -0.01, 0)
        entity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        return entity
    }

    private func makePlayerEntity() -> Entity {
        // Try loading the USDZ from the package resources (Character/Skiller.usdz)
        if let url = Bundle.module.url(forResource: "Skiller", withExtension: "usdz", subdirectory: "Character"),
           let assetEntity = try? Entity.loadModel(contentsOf: url) {
            let entity = assetEntity
            Self.normalizeModelScale(entity, targetHeight: VisualScale.playerHeight)
            entity.position = SIMD3<Float>(0, 0, 0)
            return entity
        }

        // Fallback to legacy named lookup
        if let assetEntity = try? Entity.loadModel(named: "Skiller") {
            let entity = assetEntity
            Self.normalizeModelScale(entity, targetHeight: VisualScale.playerHeight)
            entity.position = SIMD3<Float>(0, 0, 0)
            return entity
        }

        let material = SimpleMaterial(
            color: UIColor(TimberlineTheme.Scene3D.trunk),
            roughness: 0.7,
            isMetallic: false
        )
        let mesh = MeshResource.generateBox(size: SIMD3<Float>(0.6, 1.2, 0.6))
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = SIMD3<Float>(0, 0.6, 0)
        return entity
    }

    @MainActor
    private static func makeTreeEntity(species: TreeSpecies, isFelled: Bool) -> Entity {
        let assetName: String
        if isFelled {
            switch species {
            case .birch:
                assetName = "Stump_Tier1_Common"
            case .oak:
                assetName = "Stump_Tier2_Oak"
            case .willow:
                assetName = "Stump_Tier3_Willow"
            case .evergreen:
                assetName = "Stump_Tier4_Elder"
            case .ancientYew:
                assetName = "Stump_Tier4_Elder"
            case .elderwood:
                assetName = "Stump_Tier5_Enchanted"
            }
        } else {
            switch species {
            case .birch:
                assetName = "Tree_Tier1_Common"
            case .oak:
                assetName = "Tree_Tier2_Oak"
            case .willow:
                assetName = "Tree_Tier3_Willow"
            case .evergreen:
                assetName = "Tree_Tier4_Elder"
            case .ancientYew:
                assetName = "Tree_Tier4_Elder"
            case .elderwood:
                assetName = "Tree_Tier5_Enchanted"
            }
        }

        // Determine subdirectory for tree vs stump and try package resource URL
        let subdir = isFelled ? "Environment/Stumps" : "Environment/Trees"
        if let assetEntity = loadCachedModel(named: assetName, subdirectory: subdir) {
            let entity = assetEntity
            normalizeModelScale(entity, targetHeight: targetTreeHeight(for: species, isFelled: isFelled))
            entity.position = SIMD3<Float>(0, 0, 0)
            entity.name = isFelled ? "stump" : "tree"
            return entity
        }

        // Fallback to legacy named lookup
        if let assetEntity = try? Entity.loadModel(named: assetName) {
            let entity = assetEntity
            normalizeModelScale(entity, targetHeight: targetTreeHeight(for: species, isFelled: isFelled))
            entity.position = SIMD3<Float>(0, 0, 0)
            entity.name = isFelled ? "stump" : "tree"
            return entity
        }

        let material = SimpleMaterial(color: UIColor.systemGreen, roughness: 0.8, isMetallic: false)
        let mesh = MeshResource.generateBox(size: SIMD3<Float>(0.6, 2.2, 0.6))
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = SIMD3<Float>(0, 1.1, 0)
        entity.name = isFelled ? "stump" : "tree"
        return entity
    }

    @MainActor
    private static var modelPrototypeCache: [String: Entity] = [:]

    @MainActor
    private static func loadCachedModel(named assetName: String, subdirectory: String) -> Entity? {
        let cacheKey = "\(subdirectory)/\(assetName)"
        if let prototype = modelPrototypeCache[cacheKey] {
            return prototype.clone(recursive: true)
        }

        let loaded: Entity?
        if let url = Bundle.module.url(forResource: assetName, withExtension: "usdz", subdirectory: subdirectory),
           let fromURL = try? Entity.loadModel(contentsOf: url) {
            loaded = fromURL
        } else if let fromNamed = try? Entity.loadModel(named: assetName) {
            loaded = fromNamed
        } else {
            loaded = nil
        }

        guard let loaded else { return nil }
        modelPrototypeCache[cacheKey] = loaded
        return loaded.clone(recursive: true)
    }

    @MainActor
    private static func normalizeModelScale(_ entity: Entity, targetHeight: Float) {
        let currentHeight = entity.visualBounds(relativeTo: nil).extents.y
        guard currentHeight > 0.0001 else { return }
        let multiplier = targetHeight / currentHeight
        entity.scale *= SIMD3<Float>(repeating: multiplier)
    }

    private static func targetTreeHeight(for species: TreeSpecies, isFelled: Bool) -> Float {
        if isFelled { return VisualScale.stumpHeight }

        switch species {
        case .birch: return 92
        case .oak: return 90
        case .willow: return 88
        case .evergreen: return 80
        case .ancientYew: return 98
        case .elderwood: return 106
        }
    }
}
