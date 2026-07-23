import SwiftUI

/// Shared header across Swipe/Shortlist/Matches (README "Header row":
/// settings icon left · deck switcher center · count chip right). Rendered
/// once in `MainTabView`, above the segmented tab pills — not duplicated per
/// screen. `chipText` is the one thing that varies per tab ("12 left" / "12
/// saved" / "12 matches").
struct AppTopBar: View {
    let chipText: String?
    let theme: AppTheme
    let onTapSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onTapSettings) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Settings")

            DeckSwitcherMenu()

            Spacer()

            if let chipText {
                Text(chipText)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.chip, in: Capsule())
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(minHeight: 34)
    }
}
