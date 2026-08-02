# Timberline

[![Build Check](https://github.com/archubbuck/ios-gathering-game/actions/workflows/build-check.yml/badge.svg)](https://github.com/archubbuck/ios-gathering-game/actions/workflows/build-check.yml)

A medieval-fantasy woodcutting idle game for iOS, inspired by Old School
RuneScape's Woodcutting skill. Tap trees in an isometric forest, gather
logs, level from 1 to 99, and upgrade your axe from Bronze to Dragon.

Fully offline, no backend. The forest scene is a low-poly 3D world
rendered with SceneKit (procedural primitive geometry, no `.scn`/texture
assets); HUD and menus are SwiftUI. The repo contains no image assets
except the app icon.

- **Platform:** iOS 16.0+, iPhone, portrait only
- **App package:** `Timberline.swiftpm` (Xcode-compatible Swift package)
- **PRD:** [`sylvan_craft_project_prd.md`](sylvan_craft_project_prd.md)

## Gameplay

1. **Gather** — tap a tree to start chopping; each 0.6s tick rolls a
   success chance based on your level and equipped axe.
2. **Gain** — successful chops yield logs (into a 28-slot pack) and XP on
   the real OSRS curve.
3. **Progress** — levels unlock new regions (Birchwood Glade → Elderwood
   Heart) and better axes.
4. **Upgrade** — sell or bank logs; spend gold in the Axe Shop
   (Bronze → Iron → Steel → Black → Mithril → Adamant → Rune → Dragon).

## Development workflow (no Mac required)

This project is developed on a non-Mac machine; GitHub's macOS runners do
all compiling:

| Workflow | Trigger | Purpose |
|---|---|---|
| `build-check.yml` | every push touching the app | Compiles for iOS Simulator (no signing). **The primary feedback loop.** |
| `testflight.yml` | manual dispatch | Archives with manual signing and uploads to TestFlight. |
| `release-swiftpm.yml` | version tag | Attaches a zip of the `.swiftpm` to a GitHub Release. |

### TestFlight signing setup (one-time, manual)

`testflight.yml` needs these GitHub Actions secrets
(Settings → Secrets and variables → Actions):

1. `APPLE_TEAM_ID` — Apple Developer Team ID.
2. Create the App ID `com.adamchubbuck.timberline`
   (developer.apple.com → Certificates, Identifiers & Profiles).
3. `DIST_CERT_BASE64` / `DIST_KEY_BASE64` — base64 of an Apple
   Distribution certificate and its private key.
4. `DIST_PROFILE_BASE64` — base64 of an App Store provisioning profile
   for that App ID + certificate.
5. Create the app record in App Store Connect with the same bundle ID.
6. `APPLE_KEY_ID`, `APPLE_ISSUER_ID`, `APPLE_PRIVATE_KEY` — App Store
   Connect API key (Users and Access → Integrations) for upload auth.
7. Add yourself as a TestFlight internal tester.

Phases of development before the first TestFlight build run entirely
signing-free on `build-check.yml`.

## Architecture

- **MVVM, single source of truth:** `GameState` (`@MainActor
  ObservableObject`) owns XP, gold, inventory, bank, trees, achievements.
- **Engine:** `ChopEngine` runs a 0.6s tick timer only while actively
  chopping; success chance is pure math in `ChopMath`.
- **Persistence:** Codable JSON snapshot in Application Support, atomic
  writes with a `.bak` fallback, saved on change (debounced) and on
  backgrounding. No SwiftData (iOS 16 floor).
- **Balance data:** every tree/axe/region/achievement number lives in
  `Core/GameData.swift` — tuning never touches logic.
- **AI workflow:** see `AI-GUARDRAILS.md` for project-specific agent instructions,
  feature guardrails, naming conventions, and world-save determinism rules.
