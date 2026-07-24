import SwiftUI

/// Compact stamina readout for the forest HUD's top-leading corner, stacked
/// under `HPBar`. Dims and swaps its icon when empty, matching the exhausted
/// penalty applied in `GameState` (slower movement, slower chopping, and
/// HP drain if chopping continues).
struct StaminaBar: View {
    let stamina: Double
    let maxStamina: Double

    private var fraction: Double {
        guard maxStamina > 0 else { return 0 }
        return max(0, min(1, stamina / maxStamina))
    }

    private var isExhausted: Bool { stamina <= 0 }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isExhausted ? "bolt.slash.fill" : "bolt.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isExhausted ? SylvanTheme.textOnWood.opacity(0.5) : Color(hex: 0x5FC77E))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule()
                        .fill(Color(hex: 0x5FC77E))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(width: 74, height: 8)

            Text("\(Int(stamina.rounded()))")
                .font(.stat(11))
                .foregroundStyle(SylvanTheme.textOnWood)
                .monospacedDigit()
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.3)))
    }
}
