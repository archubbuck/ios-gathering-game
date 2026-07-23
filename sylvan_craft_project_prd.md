# Project Requirements Document: Sylvan Craft

## 1. Executive Summary
**Sylvan Craft** is a mobile woodcutting simulation app for iOS, heavily inspired by the "Old School RuneScape" (OSRS) woodcutting skill. The project aims to deliver a focused, high-fidelity "clicker" or "idle" experience centered on gathering resources, leveling up, and upgrading equipment within a cohesive medieval-fantasy aesthetic.

## 2. Core Gameplay Loop
1.  **Gather:** Players tap on interactive trees in a 3D isometric environment.
2.  **Gain:** Successful chopping yields resource logs and Experience Points (XP).
3.  **Progress:** Accumulating XP increases the Woodcutting Level, unlocking higher-tier trees and better equipment.
4.  **Upgrade:** Logs can be sold or banked. Gold is used to purchase superior axes (Bronze to Dragon) to increase efficiency.

## 3. Visual Identity
*   **Brand Name:** Sylvan Craft
*   **Aesthetic:** Medieval-Fantasy / Mid-Detail Vector.
*   **Key Design Tokens:**
    *   **Primary Palette:** Dark Wood (#3E2723), Forest Green (#2E7D32), Gold (#FFC107).
    *   **Surfaces:** Aged Parchment and rustic wood textures.
    *   **Typography:** *EB Garamond* (Serif) for headings; Clean Sans-Serif for stats/UI.
*   **Art Style:** 1:1 OSRS tree silhouettes rendered with modern vector gradients and clean outlines ({{DATA:IMAGE:IMAGE_2}}).

## 4. Feature Requirements

### 4.1. Woodcutting Gameplay (Core View)
*   3D Isometric forest environment.
*   Interactive tree entities (Oak, Willow, Evergreen, Birch).
*   Floating "Chop Progress" timer/circle.
*   Compact chat log for gameplay event feedback.

### 4.2. Progression & Stats
*   **Woodcutting Skill:** Level 1–99 progression.
*   **XP Scaling:** Incremental XP rewards based on tree difficulty.
*   **Achievements:** Badge-based system for milestones (e.g., "1,000 Oak Logs Chopped").

### 4.3. Inventory & Banking
*   **Inventory:** Limited 28-slot grid for active gathering.
*   **Bank:** Persistent, high-capacity storage with category filtering (Logs, Axes).
*   **Economy:** Gold (GP) currency system for shop transactions.

### 4.4. World Navigation
*   Parchment-style World Map with level-locked regions (e.g., Oak Vale, Willow Wetlands).
*   "You Are Here" marker and region difficulty indicators.

### 4.5. Equipment Shop
*   Tiered progression: Bronze > Iron > Steel > Black > Mithril > Adamant > Rune > Dragon.
*   Stat modifiers for "Chop Speed" and "Success Rate."

## 5. Technical Specifications (SwiftUI)
*   **Platform:** iOS 16.0+ (iPhone Portrait).
*   **Architecture:** MVVM with `@StateObject` for global game state (XP, Gold, Inventory).
*   **UI Framework:** SwiftUI `LazyVGrid` for inventory/banking; `ZStack` for gameplay overlays.
*   **Asset Management:** Individual sprite references provided in {{DATA:IMAGE:IMAGE_2}} for 1:1 OSRS recreations.

## 6. Key Screens Reference
*   **Gameplay:** {{DATA:IMAGE:IMAGE_31}}
*   **Inventory/Skills:** {{DATA:IMAGE:IMAGE_30}}
*   **Bank System:** {{DATA:IMAGE:IMAGE_29}}
*   **World Map:** {{DATA:IMAGE:IMAGE_28}}
*   **Axe Shop:** {{DATA:IMAGE:IMAGE_27}}
*   **Profile/Achievements:** {{DATA:IMAGE:IMAGE_24}}
*   **Settings:** {{DATA:IMAGE:IMAGE_23}}
