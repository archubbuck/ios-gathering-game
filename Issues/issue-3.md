## Issue 3: Character Animation Controller

**Labels:** `character`, `realitykit`, `core`
**Depends on:** None — character USDZ assets already exist (base, walk, run, chop, idle)
**Blocks:** Issue 2 (Tree-Felling) — chop state must exist before felling logic can trigger it

### Summary
Build a `SkillerAnimationController` that manages a single visible character entity and switches between idle / walk / run / chop animation states, driven by explicit input flags (not automatic speed-threshold detection).

### Background
- 5 USDZ files exist: base rig (bind pose), walk, run, chop, idle — each is a full mesh+skeleton+one-clip export, not a shared multi-clip file.
- Confirmed driver: **explicit input flag** (e.g. `isRunning: Bool` toggle), not inferred from movement speed.
- All 5 exports share the same underlying rig, so skeleton/joint names should match — **not yet verified in Xcode**.

### Tasks
- [ ] Load the base rig USDZ as the single visible character `Entity`.
- [ ] Load walk/run/chop/idle USDZ files off-screen at startup, purely to extract their `AnimationResource` via `entity.availableAnimations`, then discard those entities.
- [ ] Verify joint/skeleton names match across all 5 exports (manual Xcode check — flagged as unverified).
- [ ] Implement `SkillerAnimationController` with:
  - An explicit state enum: `.idle`, `.walking`, `.running`, `.chopping`.
  - A public method to set movement state, driven by explicit flags from input code (e.g. `setMovement(isMoving: Bool, isRunning: Bool)`).
  - A public method `playChop()` that interrupts movement animation, plays the chop clip once, and returns to the prior movement state on completion.
  - Smooth blending/crossfade between states (RealityKit's `.playAnimation` with `blendDuration`, or manual crossfade if unsupported).
- [ ] Wire character movement input to call `setMovement` so idle/walk/run swap correctly as the player moves.
- [ ] Wire chop input (see Issue 2) to call `playChop()`.

### Acceptance Criteria
- Character starts in idle and transitions cleanly to walk/run based on explicit flags.
- Chop animation plays fully once per trigger and returns to the correct prior state afterward (no getting stuck in chop pose).
- No visible popping/snapping between animation states (crossfade or acceptable blend).

### Notes / Caveats
- Skeleton-name matching across the 5 separate exports has not been verified — do this first, before building the full state machine, since a mismatch would block animation swapping entirely.
- If the app's minimum iOS target is decided, this may affect which RealityKit animation blending APIs are available — currently unconfirmed.
