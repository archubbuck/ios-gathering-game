import SwiftUI

/// Shared frosted-glass styling for the in-scene forest HUD: translucent
/// white panels floating over the bright 3D world. Only ForestView's
/// overlay uses this look — the rest of the app keeps its wood/parchment
/// identity.
struct HUDPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = 18
    /// Extra white laid over the blur; raise toward 1 for near-opaque
    /// panels (e.g. the message log).
    var tint: Double = 0.35

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(tint))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(TimberlineTheme.hudBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }
}

extension View {
    /// Frosted translucent HUD panel with hairline border and soft shadow.
    func hudPanel(cornerRadius: CGFloat = 18, tint: Double = 0.35) -> some View {
        modifier(HUDPanelModifier(cornerRadius: cornerRadius, tint: tint))
    }

    /// Bold white label style for text sitting directly on the 3D scene
    /// (no panel behind it) — the dark shadow keeps it legible over both
    /// bright grass and dark canopies.
    func hudSceneLabel() -> some View {
        foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
    }
}
