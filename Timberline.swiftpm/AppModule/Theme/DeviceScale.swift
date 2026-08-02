import CoreGraphics

/// A single scale factor derived from the available canvas size, used to
/// keep fixed-pixel HUD elements (minimap, level badge, stamina bar)
/// proportionate from iPhone SE up through iPad, instead of staying a
/// constant pixel size regardless of device.
enum DeviceScale {
    /// iPhone-class baseline width the original fixed HUD sizes were tuned
    /// against.
    private static let referenceWidth: CGFloat = 390

    private static let minScale: CGFloat = 0.9
    private static let maxScale: CGFloat = 1.6

    static func hud(for size: CGSize) -> CGFloat {
        guard referenceWidth > 0 else { return 1 }
        let raw = min(size.width, size.height) / referenceWidth
        return min(max(raw, minScale), maxScale)
    }
}
