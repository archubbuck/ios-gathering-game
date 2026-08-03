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

        let cameraAnchor = AnchorEntity(world: SIMD3<Float>(0, 8, 10))
        let camera = PerspectiveCamera()
        camera.transform.translation = SIMD3<Float>(0, 8, 10)
        camera.transform.rotation = simd_quatf(angle: -.pi / 4, axis: SIMD3<Float>(1, 0, 0))
        cameraAnchor.addChild(camera)

        context.coordinator.anchor = anchor
        context.coordinator.playerEntity = player
        context.coordinator.groundEntity = ground
        context.coordinator.cameraAnchor = cameraAnchor
        context.coordinator.animationController = animationController

        arView.scene.anchors.append(anchor)
        arView.scene.anchors.append(cameraAnchor)
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
        var anchor: AnchorEntity?
        var cameraAnchor: AnchorEntity?
        var playerEntity: Entity?
        var groundEntity: ModelEntity?
        var animationController: SkillerAnimationController?
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

            if let cameraAnchor {
                cameraAnchor.position = SIMD3<Float>(
                    Float(game.player.position.x),
                    8,
                    Float(game.player.position.y) + 10
                )
            }

            let visibleTrees = game.worldTrees
            var seenKeys = Set<String>()

            for tree in visibleTrees {
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
                        existing.scale = SIMD3<Float>(repeating: 0.35)
                        continue
                    }
                }

                let entity = ForestSceneView.makeTreeEntity(species: tree.species, isFelled: isFelled)
                entity.position = SIMD3<Float>(
                    Float(tree.worldPosition.x),
                    0.0,
                    Float(tree.worldPosition.y)
                )
                entity.scale = SIMD3<Float>(repeating: 0.35)
                anchor.addChild(entity)
                treeEntities[tree.key] = entity
            }

            for (key, entity) in treeEntities where !seenKeys.contains(key) {
                entity.removeFromParent()
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
            entity.scale = SIMD3<Float>(repeating: 0.08)
            entity.position = SIMD3<Float>(0, 0, 0)
            return entity
        }

        // Fallback to legacy named lookup
        if let assetEntity = try? Entity.loadModel(named: "Skiller") {
            let entity = assetEntity
            entity.scale = SIMD3<Float>(repeating: 0.08)
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
        if let url = Bundle.module.url(forResource: assetName, withExtension: "usdz", subdirectory: subdir),
           let assetEntity = try? Entity.loadModel(contentsOf: url) {
            let entity = assetEntity
            entity.scale = SIMD3<Float>(repeating: 0.35)
            entity.position = SIMD3<Float>(0, 0, 0)
            entity.name = isFelled ? "stump" : "tree"
            return entity
        }

        // Fallback to legacy named lookup
        if let assetEntity = try? Entity.loadModel(named: assetName) {
            let entity = assetEntity
            entity.scale = SIMD3<Float>(repeating: 0.35)
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
}
