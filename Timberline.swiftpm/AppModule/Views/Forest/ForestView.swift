import SwiftUI

/// The core gameplay screen: scrolling open world with a player character,
/// procedurally generated trees, proximity-based chopping, floating XP
/// drops, HUD bar (level, XP, gold, pack, stamina), and a frosted
/// in-scene overlay (minimap, Inventory/Skills shortcuts).
struct ForestView: View {
    @EnvironmentObject private var game: GameState
    @StateObject private var hudBridge = SceneHUDBridge()
    @State private var levelUpBanner: Int?
    @State private var lastSeenLevel: Int?
    /// `game.camera.zoomScale` captured at the start of the current pinch
    /// gesture, so `MagnificationGesture`'s cumulative-since-start value
    /// can be applied as a multiplier on top of it rather than replacing
    /// whatever zoom the player already had.
    @State private var pinchStartZoomScale: CGFloat?

    /// Two-finger pinch-to-zoom, applied simultaneously with the
    /// single-finger drag-to-move gesture on `ForestSceneView`.
    private var pinchToZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let base = pinchStartZoomScale ?? game.camera.zoomScale
                pinchStartZoomScale = base
                game.camera.zoomScale = Camera.clampedZoom(base * value)
            }
            .onEnded { _ in
                pinchStartZoomScale = nil
            }
    }

    var body: some View {
        GeometryReader { rootGeo in
            let hudScale = DeviceScale.hud(for: rootGeo.size)

            VStack(spacing: 0) {
                HUDBar(scale: hudScale)

                GeometryReader { _ in
                    ZStack {
                        // Low-poly 3D forest scene: ground, trees, and player.
                        // Drag-to-move attaches to the scene itself (not the
                        // ZStack) so overlay buttons stay clean tap targets.
                        // Pinch-to-zoom is layered on as a simultaneous gesture
                        // so it doesn't steal touches from drag-to-move.
                        ForestSceneView(hudBridge: hudBridge)
                            .playerMovement()
                            .simultaneousGesture(pinchToZoomGesture)

                        // Chop/dwell progress ring above whichever tree is
                        // relevant, projected from 3D by SceneHUDBridge.
                        if let point = hudBridge.screenPoint, let target = hudBridge.target {
                            ChopDwellOverlay(target: target, axeTier: game.equippedAxe)
                                .position(point)
                                .zIndex(9)
                        }

                        // XP drop overlay above the active tree.
                        if let drop = game.lastXPDrop, let point = hudBridge.screenPoint {
                            XPDropOverlay(drop: drop)
                                .id(drop.id)
                                .position(x: point.x, y: point.y - 20)
                                .zIndex(10)
                        }

                        // Level-up celebration banner.
                        if let level = levelUpBanner {
                            LevelUpBanner(level: level)
                                .zIndex(20)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }

                        // Woodcutting-level-too-low warning toast.
                        if let warning = game.levelGateWarning {
                            LevelGateToast(warning: warning)
                                .id(warning.id)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(.top, 8)
                                .zIndex(20)
                        }

                        // Minimap, top-trailing.
                        MinimapView(scale: hudScale)
                            .padding(10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .zIndex(15)

                        // Watch Ad prompt, floating bottom-leading (opposite the
                        // minimap) so it never shifts other HUD content.
                        AdBoostFloatingButton()
                            .padding(14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .zIndex(15)

                        // Feedback toasts (pack full, tree unavailable).
                        if let notice = game.feedbackNotice {
                            FeedbackToast(notice: notice)
                                .id(notice.id)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .padding(.bottom, 60)
                                .zIndex(18)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // Save-error banner.
                        if game.saveError != nil {
                            SaveErrorBanner()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .padding(.bottom, 4)
                                .zIndex(22)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .clipped()
                    // Frosted materials must read as *white* glass even when the
                    // device is in dark mode; the SCNView ignores this.
                    .environment(\.colorScheme, .light)
                }
            }
            .background(TimberlineTheme.hudBackground)
        }
        .onAppear {
            if lastSeenLevel == nil {
                lastSeenLevel = game.level
            }
        }
        .onChange(of: game.level) { newLevel in
            defer { lastSeenLevel = newLevel }
            guard let last = lastSeenLevel, newLevel > last else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                levelUpBanner = newLevel
            }
            Task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.5)) {
                        if levelUpBanner == newLevel {
                            levelUpBanner = nil
                        }
                    }
                }
            }
        }
        .onChange(of: game.feedbackNotice) { notice in
            guard notice != nil else { return }
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.4)) {
                        if game.feedbackNotice?.id == notice?.id {
                            game.feedbackNotice = nil
                        }
                    }
                }
            }
        }
        .onChange(of: game.saveError != nil) { hasError in
            guard hasError else { return }
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await MainActor.run {
                    withAnimation { game.saveError = nil }
                }
            }
        }
    }
}

/// Celebration banner flashed over the scene on level-up.
private struct LevelUpBanner: View {
    let level: Int

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 22))
                .foregroundStyle(TimberlineTheme.gold)
            Text("Level \(level)!")
                .font(.display(30))
                .foregroundStyle(TimberlineTheme.gold)
            Text("Woodcutting")
                .font(.stat(13))
                .foregroundStyle(TimberlineTheme.textOnWood.opacity(0.85))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .woodPanel()
        .shadow(color: TimberlineTheme.gold.opacity(0.5), radius: 18)
        .allowsHitTesting(false)
    }
}

/// The single chop-depletion or dwell-approach indicator, positioned at
/// `SceneHUDBridge`'s projected screen point: a frosted disc holding the
/// equipped axe's art, wrapped in a green progress ring, with bold
/// "CHOPPING…" status text beneath.
private struct ChopDwellOverlay: View {
    let target: SceneHUDBridge.Target
    let axeTier: AxeTier

    var body: some View {
        switch target {
        case .chopping(let progress):
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .background(Circle().fill(TimberlineTheme.hudPanelTint))
                        .overlay(Circle().strokeBorder(TimberlineTheme.hudBorder, lineWidth: 1))
                        .frame(width: 56, height: 56)
                    AxeArt(tier: axeTier)
                        .scaleEffect(0.62)
                    ProgressRing(
                        progress: progress,
                        tint: TimberlineTheme.hudStamina,
                        track: .white.opacity(0.5),
                        lineWidth: 6
                    )
                    .frame(width: 64, height: 64)
                }
                VStack(spacing: 0) {
                    Text("CHOPPING...")
                        .font(.stat(12, weight: .heavy))
                        .kerning(0.5)
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.stat(14, weight: .heavy))
                        .monospacedDigit()
                }
                .hudSceneLabel()
            }
            .allowsHitTesting(false)

        case .dwelling(let progress):
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.85), lineWidth: 2.5)
                    .frame(width: 72, height: 72)
                    .scaleEffect(0.7 + CGFloat(progress) * 0.25)
                    .opacity(0.9)
                    .animation(.easeInOut(duration: 0.3), value: progress)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                ProgressRing(
                    progress: progress,
                    tint: TimberlineTheme.hudStamina,
                    track: .white.opacity(0.5)
                )
                .frame(width: 28, height: 28)
                .background(Circle().fill(.ultraThinMaterial))
            }
            .allowsHitTesting(false)
        }
    }
}

/// Non-blocking toast for pack-full, tree-unavailable, and similar feedback.
private struct FeedbackToast: View {
    let notice: FeedbackNotice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(message)
                .font(.stat(13, weight: .semibold))
                .foregroundStyle(TimberlineTheme.hudTextDark)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .background(Capsule().fill(TimberlineTheme.hudPanelTint))
                .overlay(Capsule().strokeBorder(TimberlineTheme.hudBorder, lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .allowsHitTesting(false)
        .accessibilityLabel(message)
    }

    private var iconName: String {
        switch notice.kind {
        case .packFull:       return "tray.full.fill"
        case .treeUnavailable: return "hourglass"
        case .loadingChunks:  return "arrow.clockwise"
        }
    }

    private var tint: Color {
        switch notice.kind {
        case .packFull:       return TimberlineTheme.hudLogWarning
        case .treeUnavailable: return TimberlineTheme.forestGreen.opacity(0.7)
        case .loadingChunks:  return TimberlineTheme.hudTextDark.opacity(0.6)
        }
    }

    private var message: String {
        switch notice.kind {
        case .packFull:
            return "Pack full"
        case .treeUnavailable(let species):
            return "\(species.displayName) is still regrowing"
        case .loadingChunks:
            return "Loading forest…"
        }
    }
}

/// Slim banner shown when a save write fails; stays visible until dismissed
/// automatically after 4 s.
private struct SaveErrorBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TimberlineTheme.hudLogWarning)
            Text("Save failed — progress may be lost")
                .font(.stat(12, weight: .semibold))
                .foregroundStyle(TimberlineTheme.hudTextDark)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.95))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(TimberlineTheme.hudLogWarning).opacity(0.6),
                 alignment: .top)
        .allowsHitTesting(false)
        .accessibilityLabel("Save failed. Your recent progress may not be stored.")
    }
}
