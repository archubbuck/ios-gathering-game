import SwiftUI

private struct ParchmentCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(TimberlineTheme.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(TimberlineTheme.parchmentEdge, lineWidth: 2)
                    )
                    .shadow(color: TimberlineTheme.darkWood.opacity(0.15), radius: 3, y: 2)
            )
    }
}

private struct WoodPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [TimberlineTheme.woodPanelTop, TimberlineTheme.woodPanelBottom],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(TimberlineTheme.darkWood, lineWidth: 2)
                    )
            )
    }
}

extension View {
    func parchmentCard() -> some View { modifier(ParchmentCard()) }
    func woodPanel() -> some View { modifier(WoodPanel()) }
}
