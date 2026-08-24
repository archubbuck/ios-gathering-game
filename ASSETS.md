# ASSETS.md

Reference index for the assets used by the 2D woodcutting game.

The forest is rendered with SpriteKit. Player, trunk, and stump artwork is
created from `SKNode`/`SKSpriteNode` hierarchies in
`Views/Forest/ForestSceneView.swift`; the former 3D USDZ exports are not
bundled or loaded.

## Folder structure

```text
Resources/
├── Environment/
│   ├── LeafSprites/
│   │   ├── Leaf_Tier1.png
│   │   ├── Leaf_Tier2.png
│   │   ├── Leaf_Tier3.png
│   │   ├── Leaf_Tier4.png
│   │   └── Leaf_Tier5.png
│   └── Ground/
│       └── Grass_Tileable.png
```

## Environment art

| Asset | File | Usage |
|---|---|---|
| Leaf sprites | `LeafSprites/Leaf_Tier1.png` … `Leaf_Tier5.png` | Canopy textures and hit effects |
| Ground texture | `Environment/Ground/Grass_Tileable.png` | Streamed SpriteKit ground tiles |
| Tree trunks and canopies | `ForestSceneView` | Procedural 2D nodes, sized per species |
| Felled stumps | `ForestSceneView` | Procedural 2D ellipse nodes |

Each tree tier uses its matching leaf sprite. Species colors, trunk colors, and
node dimensions are centralized in `TimberlineTheme.SceneArt` and the
per-species helpers in `ForestSceneView`.

## Character art

The player is a lightweight 2D node hierarchy styled as an orange-haired,
green-scarfed adventurer: backpack, blue shirt, leather tunic, brown trousers,
red boots, side-profile face, and bronze axe. The silhouette is assembled from
flat SpriteKit polygons and sprites in `Views/Forest/ForestSceneView.swift`.
`SkillerAnimationController` tracks idle, walking, and chopping states; chop
feedback is an `SKAction` shake rather than a skeletal animation.

## Format guide

- **PNG** — SpriteKit and particle textures.
- **Swift** — procedural 2D scene art and animation state.

No SceneKit or RealityKit model assets are required by the 2D renderer.
