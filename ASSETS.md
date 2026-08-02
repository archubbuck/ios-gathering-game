# ASSETS.md
Reference index for all game-ready assets used in the woodcutting skiller prototype.
All assets were generated via Meshy. USDZ is the primary format for RealityKit import;
GLB/FBX originals are kept as source backups for re-export if ever needed.

---

## 📁 Folder Structure (suggested)

Resources/
├── Character/
│   ├── Skiller.usdz              # base rigged character (bind pose)
│   ├── Skiller_Idle.usdz         # calm idle loop
│   ├── Skiller_Walk.usdz
│   ├── Skiller_Run.usdz
│   ├── Skiller_Chop.usdz
│   └── source/                   # GLB/FBX originals kept for re-export if needed
├── Environment/
│   ├── Trees/
│   │   ├── Tree_Tier1_Common.usdz
│   │   ├── Tree_Tier2_Oak.usdz
│   │   ├── Tree_Tier3_Willow.usdz
│   │   ├── Tree_Tier4_Elder.usdz
│   │   ├── Tree_Tier5_Enchanted.usdz
│   │   └── source/                # GLB originals
│   ├── Stumps/
│   │   ├── Stump_Tier1_Common.usdz
│   │   ├── Stump_Tier2_Oak.usdz
│   │   ├── Stump_Tier3_Willow.usdz
│   │   ├── Stump_Tier4_Elder.usdz
│   │   ├── Stump_Tier5_Enchanted.usdz
│   │   └── source/                # GLB originals
│   ├── LeafSprites/
│   │   ├── Leaf_Tier1.png
│   │   ├── Leaf_Tier2.png
│   │   ├── Leaf_Tier3.png
│   │   ├── Leaf_Tier4.png
│   │   └── Leaf_Tier5.png
│   └── Ground/
│       └── Grass_Tileable.png
└── Concepts/                     # 2D reference renders, not shipped in app bundle
    └── ... (concept art per tier, kept for art-direction reference only)

---

## 🧍 Character: "Skiller"

Original adventurer character, custom design (not derived from any existing game's IP).
Fitted jacket + separated trouser legs + flat collar, A-pose base — optimized for
rigging/animation compatibility. Carries a hero hatchet prop as the primary tool.

| Asset | File | Format | Notes |
|---|---|---|---|
| Base rig | `Skiller.usdz` | USDZ | Bind pose, RealityKit-ready |
| Idle | `Skiller_Idle.usdz` | USDZ | Calm, arms relaxed, loopable — default state when not moving/attacking |
| Walk cycle | `Skiller_Walk.usdz` | USDZ | Loopable |
| Run cycle | `Skiller_Run.usdz` | USDZ | Loopable |
| Chop attack | `Skiller_Chop.usdz` | USDZ | Overhead strike, single-shot, non-looping |

**Source/backup formats:** GLB + FBX versions of all five above are also available if
re-rigging or a non-Apple pipeline is ever needed.

**Animation transfer note:** Idle/Walk/Run/Chop were generated as separate USDZ files
sharing the same skeleton as the base rig. In RealityKit you'll need to load each and
transfer/play their `AnimationResource`s onto the base entity via a controller — see the
`SkillerAnimationController` design (state enum: idle/walking/running/chopping, explicit
`setState()` API, chop plays via `playChop()` and cannot be interrupted mid-swing).

---

## 🌳 Trees & Stumps (5 tiers)

Unified stylized low-poly art direction across all tiers, consistent with the character's
look. Each tier = one tree + one matching stump (post-felling) + one leaf sprite (for the
hit-shake/particle burst effect). All 10 tree/stump models are available in USDZ.

| Tier | Theme | Tree file | Stump file | Leaf sprite |
|---|---|---|---|---|
| 1 | Common Tree | `Tree_Tier1_Common.usdz` | `Stump_Tier1_Common.usdz` | `Leaf_Tier1.png` |
| 2 | Oak-type | `Tree_Tier2_Oak.usdz` | `Stump_Tier2_Oak.usdz` | `Leaf_Tier2.png` |
| 3 | Willow-type | `Tree_Tier3_Willow.usdz` | `Stump_Tier3_Willow.usdz` | `Leaf_Tier3.png` |
| 4 | Elder/Ancient | `Tree_Tier4_Elder.usdz` | `Stump_Tier4_Elder.usdz` | `Leaf_Tier4.png` |
| 5 | Enchanted (teal-blue glow) | `Tree_Tier5_Enchanted.usdz` | `Stump_Tier5_Enchanted.usdz` | `Leaf_Tier5.png` |

**Tier 3 note:** shipped tree is v3 of the concept. v1/v2 mesh attempts had thin overlapping
leaf-strand geometry that caused mottled/patchy baked textures — resolved by simplifying to
chunkier rounded foliage lobes before final mesh + texture pass. Don't reuse the old
thin-strand topology if regenerating this tier later.

**Tier 5 note:** canopy color was tuned down from an initial over-saturated version to a
muted teal-blue glow. **Stump top-ring detail was not visually confirmed** (available render
angles were front/right only, no top-down) — accepted as "good enough" without full
verification. Worth a manual look in-editor before finalizing tier art.

**Gameplay behavior (for reference, implemented in code not assets):**
- Multiple axe swings are required to fell a tree (tree → stump swap is a code-driven
  transform animation, not a skeletal animation baked into the GLB/USDZ).
- Each hit triggers a leaf-shake / particle-burst effect using the tier's leaf sprite.
- Felling and hit-reaction logic live in Swift, not in the model files — these are static
  meshes only.
- Chop hits should be triggered via `SkillerAnimationController.playChop()`, not by
  duplicating chop-animation logic inside the tree/felling system.
- Tree world placement is procedural and deterministic (seeded per world), not manually
  authored — see Issue 4 below. Tier distribution follows noise-based "forest patches."

---

## 🌱 Ground

| Asset | File | Format | Notes |
|---|---|---|---|
| Grass ground texture | `Grass_Tileable.png` | PNG | Seamless tileable, applied to a flat plane grid (not a single giant plane) via the `GroundTileGenerator` |

**⚠️ Unverified:** seamless tiling has not been tested on an actual tiled plane in
RealityKit — please confirm visually (check for seams/edges) once wired up.

**Not included / deferred:** scattered ground props (rocks, grass tufts, flowers) were
discussed as an option but not generated — ground is texture-only for now.

---

## 🗂 Format Guide

- **USDZ** — primary format for all RealityKit assets: character (+ 4 animations) and
  all 10 tree/stump models across 5 tiers. Load via `Entity(named:)` / `ModelEntity`.
- **GLB** — kept as source backup for every USDZ above; convert back from GLB if a USDZ
  ever needs regenerating (e.g. after a texture/mesh fix).
- **FBX** — cross-pipeline backup for the character rig only, not used directly in the
  iOS app.
- **PNG** — leaf sprites and ground texture; used as sprite textures / particle textures /
  material base color maps.

---

## 🧩 Related GitHub Issues (drafted, not yet filed/implemented)

1. **Ground Tile Generator** — `GroundTileGenerator` grid-of-tiles ground system with
   shared collision plane, using `Grass_Tileable.png`.
2. **Tree-Felling & Stump-Swap Logic** — collision-triggered multi-swing chop detection,
   leaf-burst hit effect, tree→stump transform swap per tier. Calls into the animation
   controller's `playChop()` rather than duplicating chop logic.
3. **Character Animation Controller** — `SkillerAnimationController` managing
   idle/walk/run/chop state switching via explicit `setState()` API (no speed inference)
   plus a dedicated `playChop()` that can't be interrupted mid-swing.
4. **Procedural Tree Placement** — `ChunkTreeGenerator` + `WorldTreeStreamer` for
   deterministic, seed-based, chunk-streamed tree placement with noise-driven tier
   "forest patches" (Minecraft-style explore-freely world gen). Uses a custom
   SplitMix64-based RNG/hash — explicitly avoids Swift's default `Hasher`, which is
   randomized per process launch and would break determinism. Depends on the World Save
   & Seed system below for persisting the world seed and felled-tree state.

**Suggested merge order:** Animation Controller (3) → Tree-Felling (2, depends on 3's
`playChop()`) → Procedural Placement (4, depends on 2's felled-ID reporting hook and on
World Save & Seed below) → Ground Tile Generator (1, no dependencies on the others, can
be done anytime).

---

## 💾 World Save & Seed

No pre-existing save-game system in this project — `WorldSave` / `WorldSaveStore`
(scaffolded in this conversation) is the actual persistence layer, not a placeholder.

| Concern | Approach |
|---|---|
| World seed | Generated once via `SystemRandomNumberGenerator` at **world creation only** (`WorldSave.createNew()`), then persisted to disk and reused forever after — never regenerated on subsequent launches. |
| Storage | JSON file in the app's Documents directory (`WorldSaveStore`), keyed by save name. Swap for a different backend later if needed (e.g. iCloud sync) — the `WorldSave` struct itself is storage-agnostic (`Codable`). |
| Felled trees | `WorldSave.felledTreeIDs: Set<UInt64>` — loaded into `WorldTreeStreamer.felledTreeIDs` at world load, updated + re-saved whenever the felling system reports a newly felled tree ID. |
| Load flow | `WorldSaveStore().loadOrCreate()` — returns the existing save if found, otherwise creates and persists a brand-new one (new seed) transparently. Call this once at app/scene startup, before constructing `ChunkTreeGenerator`/`WorldTreeStreamer`. |

**⚠️ Determinism rule:** `SystemRandomNumberGenerator` must appear **exactly once**
in the entire codebase — inside `WorldSave.createNew()`. Every other random-feeling
value in world generation (chunk contents, noise sampling, tree jitter) must derive
from the persisted `worldSeed` via the seeded `SplitMix64` RNG. If this rule is ever
violated (e.g. someone "fixes" a bug by swapping in `Int.random` inside
`ChunkTreeGenerator`), determinism breaks silently — worth a code comment at each
seeded RNG call site pointing back to this rule.

**Not yet decided / defer if not needed soon:**
- Multiple save slots (currently single fixed file name `"world.json"`).
- Cloud sync / cross-device save transfer.
- Save-file versioning/migration (if `WorldSave`'s shape changes later, old saves
  will fail to decode — add a schema version field before shipping if this is a
  real concern).

---

## ⚠️ General Caveats (apply to all assets above)

- **All USDZ thumbnails render flat grey/untextured in Meshy's preview tool**, while the
  source GLBs show full color/texture correctly. This affected every USDZ conversion in
  this project (character × 5 animations + all 10 environment models) and is most likely a
  preview-only rendering limitation — but it has **not been confirmed** against an actual
  RealityKit/Xcode load. **Verify texture fidelity in Xcode / AR Quick Look for at least one
  asset per category (character, one tree, one stump) before assuming the rest are fine.**
  If any come in genuinely untextured, the fix is to re-export from the GLB source, not to
  redo the whole pipeline.
- None of these assets have been tested inside an actual Xcode/RealityKit build — visual/
  textural fidelity, collision shapes, and pivot/anchor points should be manually verified
  after import.
- No asset here is dimensionally exact — trees/character/props are shape-and-style
  references. Scale them in-editor (RealityKit `Entity.scale`) to match your game's world
  scale.
- Repair/remesh operations (if ever run on these models) will drop existing textures —
  don't re-run those on final assets without re-texturing afterward.
- None of the four drafted issues above have automated tests — each explicitly calls for
  manual verification in its acceptance criteria before merging.
- **Determinism warning (procedural placement):** any world-gen code must avoid Swift's
  default `Hasher`/`hashValue` and `SystemRandomNumberGenerator` (except the single
  sanctioned use in `WorldSave.createNew()`) — both are randomized per process launch and
  will silently break seed reproducibility across app runs.
