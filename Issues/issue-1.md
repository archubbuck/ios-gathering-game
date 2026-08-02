## Issue 1: Ground Tile Generator

**Labels:** `environment`, `realitykit`, `enhancement`
**Depends on:** None (can be built first or in parallel)
**Blocks:** Issue 4 (Procedural Tree Placement) — trees are placed relative to ground tiles

### Summary
Build a `GroundTileGenerator` that tiles the approved seamless grass texture across a flat plane (or grid of plane chunks) so the player has walkable ground that extends indefinitely as they explore, without needing one giant plane or texture.

### Background
- Ground texture asset: `Ground/Grass_Tile.png` — approved seamless tileable grass texture.
- The game needs a Minecraft-style "explore freely" ground, so tiles should generate/extend on demand rather than being one fixed-size plane.

### Tasks
- [ ] Import `Grass_Tile.png` into the RealityKit asset catalog / bundle.
- [ ] Create a `GroundTileGenerator` that:
  - Generates a single ground tile as a `ModelEntity` with a `PlaneMesh` (or subdivided grid mesh) sized to a configurable `tileSize` (e.g. 10m × 10m).
  - Applies the grass texture as an unlit or simple-lit `PhysicallyBasedMaterial`, with UV tiling repeated across the plane surface (not stretched).
  - Exposes a method to spawn/remove tiles at given grid coordinates, keyed by `(chunkX, chunkZ)`.
- [ ] Wire tile spawning to the same chunk-coordinate system used by `WorldTreeStreamer` (Issue 4) so ground and trees stream together.
- [ ] Add a `StaticCollisionComponent` (or equivalent) to each tile so the player capsule/collider can walk on it and raycasts (e.g. for placing trees, or ground-snapping the character) resolve correctly.
- [ ] Verify no visible seams between adjacent tiles at runtime.

### Acceptance Criteria
- Player can walk across multiple adjacent tiles with no visual seam or texture stretching.
- Tiles are generated lazily (only near the player) and removed/pooled when far away, to avoid unbounded scene growth.
- Tile size and streaming radius are configurable constants, not hardcoded magic numbers.

### Notes / Caveats
- Actual seamless tiling of `Grass_Tile.png` in RealityKit has not been verified yet — spot-check this first before building the full streaming system on top of it.
- Reuse the same chunk-coordinate math as the tree streamer (Issue 4) to keep ground and vegetation streaming in sync.
