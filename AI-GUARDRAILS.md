# Timberline AI Guardrails

This project uses a deterministic procedural world and a single-player persistence model.
These guardrails help AI-driven development stay aligned with the intended architecture.

## Terminology

- `Timberline`: the app name and package name.
- `WorldSave`: the persisted world state containing `worldSeed` and `felledTreeIDs`.
- `WorldSaveStore`: the singleton persistence layer that loads or creates the world save.
- `GameState`: the app's single source of truth for player progression and active world state.
- `GameData`: tuning constants for tree/axe balance and world generation.

## Key rules

1. `SystemRandomNumberGenerator` must only appear once in world seed creation.
   - Valid location: `WorldSave.newWorld`.
   - Invalid locations: any tree placement, chunk generation, or in-game deterministic systems.

2. `GameData.worldSeed` must derive from `WorldSaveStore.current.worldSeed`.
   - Do not hardcode a constant world seed anywhere else.

3. `WorldSave.felledTreeIDs` is authoritative for tree state persistence.
   - Chopped trees must be marked by key and preserved on relaunch.
   - If a tree is felled, it should load as a stump via `WorldGenerator`.

4. Save persistence lives in Application Support under `Timberline`.
   - Player progress is stored by `SaveManager`.
   - World layout and felled-tree state is stored by `WorldSaveStore`.

## Feature implementation guidance

- New world-gen code should be pure and deterministic.
- Use `SeededRandom` or another seeded RNG derived from `worldSeed`.
- Avoid `Int.random(in:)`, `Double.random(in:)`, or other non-deterministic APIs in deterministic pipelines.
- Use `WorldSaveStore.current` rather than `WorldSaveStore.load()` inside runtime logic.

## Workspace conventions

- App package: `Timberline.swiftpm`
- Swift entrypoint: `Timberline.swiftpm/AppModule/TimberlineApp.swift`
- UI views: `Timberline.swiftpm/AppModule/Views`
- Core logic: `Timberline.swiftpm/AppModule/Core`

## Development notes

- For reset/new-game flows, call both `SaveManager.wipe()` and `WorldSaveStore.wipe()`.
- When persisting a felled tree, write the updated `WorldSaveStore.current` immediately.
- Maintain the world seed once generated: do not regenerate on app launch if `world.json` exists.
