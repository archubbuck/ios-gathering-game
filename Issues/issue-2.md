## Issue 2: Tree-Felling & Stump-Swap Logic

**Labels:** `gameplay`, `realitykit`, `woodcutting`
**Depends on:** Issue 3 (Character Animation Controller) — needs the chop animation/state hook
**Blocks:** Issue 4 (Procedural Tree Placement) — felled-tree state must exist before placement can track "already chopped" trees

### Summary
Implement the core woodcutting loop: detect when the player is within chopping range of a tree, trigger multiple chop swings, shake loose leaf sprites on hit, and swap the tree model for its matching stump once felled.

### Background
- Confirmed approach: **collision-based** detection (not raycast) — player enters a trigger volume around the tree to enable chopping.
- Multiple swings required to fell a tree (not one-hit).
- Leaves should visually shake/fall when hit with the axe.
- Each tree tier has a matching stump asset already generated (Tiers 1–5).

### Tasks
- [ ] Add a `CollisionComponent` trigger volume around each tree's trunk (cylinder or box, sized per tier).
- [ ] On player-enter: expose a "choppable" state (e.g. `nearbyTree: TreeInstance?`) that the input/animation layer can query.
- [ ] On chop input while `nearbyTree != nil`:
  - Play the chop animation via `SkillerAnimationController`.
  - On animation impact frame (or a fixed delay), register one "hit" against the tree's hit counter.
  - Trigger a leaf-shake effect (leaf sprite particles or a quick canopy jiggle) on each hit.
- [ ] Define `hitsToFell` per tier (e.g. Tier 1 = 3 hits, Tier 5 = 8 hits — tune per tier difficulty).
- [ ] On reaching `hitsToFell`:
  - Remove/hide the tree entity.
  - Spawn the matching stump entity at the same position/rotation.
  - Award wood + update inventory — **stubbed as a hook only**, actual inventory logic is app-specific and out of scope for this issue.
  - Mark the tree instance as "felled" in `WorldSave` (felled-tree ID tracking) so it persists across app restarts.
- [ ] (Optional, later tier) Support tree regrowth after a cooldown timer, swapping stump back to tree.

### Acceptance Criteria
- Walking away and re-approaching a tree mid-chop does not lose hit progress unexpectedly (or explicitly resets it — decide and document behavior).
- Felled trees show the correct tier-matching stump, not a generic one.
- Felled state survives app restart (backed by `WorldSave`).
- Leaf shake is visually noticeable on each hit, distinct from the felling swap itself.

### Notes / Caveats
- Collision trigger sizing per tier has not been tuned — start with a rough capsule/box and adjust by feel during playtesting.
- Leaf-shake VFX implementation (`ParticleEmitterComponent` vs. manual sprite-plane swap) is still open, pending confirmation of minimum iOS deployment target.
