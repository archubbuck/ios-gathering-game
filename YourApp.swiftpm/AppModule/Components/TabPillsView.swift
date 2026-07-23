import SwiftUI

/// Shared across `MainTabView` and every screen that needs to know which tab
/// is active. Replaces the private `Tab` enum that used to live inside
/// `MainTabView` now that the segmented pills (not just the hidden
/// `TabView`) need to reference it.
enum AppTab: Hashable {
    case swipe, shortlist, matches
}

/// The mockup's 3-equal-pill segmented control, replacing the system tab
/// bar (README: "Segmented tabs (Swipe active): 3 equal pills, active =
/// accent/white, inactive = white/#7b83a3, radius 14").
struct TabPillsView: View {
    @Binding var selection: AppTab
    let theme: AppTheme

    private let tabs: [(AppTab, String)] = [
        (.swipe, "Swipe"),
        (.shortlist, "Shortlist"),
        (.matches, "Matches"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.0) { tab, label in
                let isActive = selection == tab
                Button {
                    selection = tab
                } label: {
                    Text(label)
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isActive ? .white : AppTheme.textSecondary)
                        .background(
                            isActive ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Color.white),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
