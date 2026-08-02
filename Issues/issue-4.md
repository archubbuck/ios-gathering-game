## Issue 4: Procedural Tree Placement (Deterministic, Chunk-Streamed)

**Labels:** `worldgen`, `realitykit`, `core`
**Depends on:** Issue 1 (Ground Tile Generator) for shared chunk-coordinate system; Issue 2 (Tree-Felling) for felled-tree ID tracking to suppress respawn
**Blocks:** None (last in the recommended merge order: 3 → 2 → 4 → 1, though ground can be built in parallel)

### Summary
Generate tree placement procedurally using seeded noise so the world is explorable in any direction (Minecraft-style), while remaining fully deterministic per save file — the same seed always produces the same forest layout, and chunks stream in/out around the player.

### Background
- Confirmed approach: **noise-based patches** for tier distribution (not simple distance-based rings) — creates natural-feeling clusters of each tree tier rather than concentric bands.
- Confirmed streaming radius: default `loadRadius = 2` chunks around the player (sensible default, not user-specified — adjustable later).
- Confirmed seed policy: **per-save-file** — each new game generates a random `worldSeed` at creation time, then it's fixed forever for that save (see `WorldSave`/`WorldSaveStore`).
- No existing save-game system in the repo — this introduces the first persistence layer.

### Tasks
- [ ] Implement `SplitMix64` (fast seeded PRNG) and `SeededNoise2D` (deterministic 2D value-noise, seeded from `worldSeed`) as pure, side-effect-free utilities.
- [ ] Implement `combineSeed(worldSeed, chunkX, chunkZ)` so each chunk's tree layout is deterministic and independent of generation order.
- [ ] Implement `ChunkTreeGenerator`:
  - For a given chunk coordinate, sample the noise field to decide tree density and tier "patch" (which tier dominates that area).
  - Generate tree instance positions/rotations/tier within the chunk deterministically from the combined seed.
  - Skip/mark positions whose tree ID is already in the save's felled-tree set (from Issue 2) — show stump instead, or skip regrowth-eligible trees per design.
- [ ] Implement `WorldTreeStreamer`:
  - Tracks player position, computes current chunk coordinate.
  - Loads (generates + instantiates) chunks within `loadRadius`, unloads chunks outside it.
  - Reuses `ChunkTreeGenerator` output to spawn tree/stump USDZ entities at computed transforms.
- [ ] Implement `WorldSave` (per-save-file `worldSeed`, felled-tree ID set, schema version placeholder) and `WorldSaveStore` (JSON persistence to disk, load-on-launch, create-on-new-game).
- [ ] Wire streamer chunk coordinates to match the Ground Tile Generator's chunk system (Issue 1) so ground and trees stay spatially aligned.

### Acceptance Criteria
- **Restart-determinism test**: walk to a chunk, note the tree layout, force-quit and relaunch the app with the same save, confirm the layout is pixel-for-pixel identical.
- Chunks load/unload smoothly as the player moves, with no visible pop-in stutter during normal walking speed (running speed may be acceptable to have minor pop-in, revisit if playtesting flags it).
- Felled trees remain stumps after restart (integrates with Issue 2's persistence).
- New game (fresh save) produces a different, still-deterministic layout each time.

### Notes / Caveats
- Determinism relies on avoiding Swift's `Hasher` (seeded randomly per process) and `SystemRandomNumberGenerator` anywhere in the noise/placement path — only `SplitMix64` and the custom seeded noise should drive tree placement.
- If forest patches look too grid-aligned or artificial, consider swapping the simple value-noise implementation for a proper simplex/Perlin noise library later — not required for first pass.
- If chunk generation causes hitches during playtesting, consider moving it off the main thread — not required for first pass, flagged as a possible follow-up.
- Save-file versioning/schema migration and multiple save slots / cloud sync are explicitly deferred — not needed until `WorldSave`'s shape actually changes or multi-slot support is requested.
