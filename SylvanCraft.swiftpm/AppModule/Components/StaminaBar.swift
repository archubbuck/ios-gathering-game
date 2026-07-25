import SwiftUI

/// Frosted stamina pill for the forest HUD. Dims and swaps its icon
/// when empty, matching the exhausted penalty applied in `GameState`
/// (slower movement and slower chopping).
struct StaminaBar: View {
    let stamina: Double
    let maxStamina: Double

    private var fraction: Double {
        guard maxStamina > 0 else { return 0 }
        return max(0, min(1, stamina / maxStamina))
    }

    private var isExhausted: Bool { stamina <= 0 }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: isExhausted ? "bolt.slash.fill" : "bolt.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            isExhausted
                                ? SylvanTheme.hudTextDark.opacity(0.4)
                                : SylvanTheme.hudStamina
                        )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("STAMINA")
                    .font(.stat(10, weight: .heavy))
                    .kerning(0.5)
                    .foregroundStyle(SylvanTheme.hudTextDark.opacity(0.85))

                ZStack(alignment: .leading) {
                    Capsule().fill(SylvanTheme.hudTrack)
                    Capsule()
                        .fill(SylvanTheme.hudStamina)
                        .frame(width: 150 * fraction)
                    Capsule().strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                }
                .frame(width: 150, height: 16)
                .overlay(
                    Text("\(Int(stamina.rounded()))/\(Int(maxStamina.rounded()))")
                        .font(.stat(10, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .hudPanel(cornerRadius: 16)
    }
}
