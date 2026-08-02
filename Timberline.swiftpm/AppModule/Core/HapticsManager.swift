import UIKit

/// Chop feedback without audio assets. Reads the same UserDefaults key
/// `SettingsStore` writes, so the Settings toggle applies immediately.
@MainActor
enum Haptics {
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
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
