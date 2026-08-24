import UIKit

/// Chop feedback without audio assets. Reads the same UserDefaults key
/// `SettingsStore` writes, so the Settings toggle applies immediately.
/// Respects `UIAccessibility.isReduceMotionEnabled` as a proxy for reduced
/// physical feedback on devices that support it; also honours the explicit
/// user preference.
@MainActor
enum Haptics {
    private static var isEnabled: Bool {
        // User has explicitly disabled haptics in Settings.
        guard UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
        else { return false }
        // Honour the system reduced-haptics preference (iOS 17+).
        if #available(iOS 17, *) {
            return !UIAccessibility.isReduceMotionEnabled
        }
        return true
    }

    /// A successful chop tick.
    static func chop() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A tree falling, a purchase, a deposit.
    static func thud() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Level-up or achievement unlocked.
    static func fanfare() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Action rejected (pack full, not enough gold).
    static func reject() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
