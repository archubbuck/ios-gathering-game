import SwiftUI

private struct ParchmentCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(SylvanTheme.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(SylvanTheme.parchmentEdge, lineWidth: 2)
                    )
                    .shadow(color: SylvanTheme.darkWood.opacity(0.15), radius: 3, y: 2)
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
                            colors: [SylvanTheme.woodPanelTop, SylvanTheme.woodPanelBottom],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(SylvanTheme.darkWood, lineWidth: 2)
                    )
            )
    }
}

extension View {
    func parchmentCard() -> some View { modifier(ParchmentCard()) }
    func woodPanel() -> some View { modifier(WoodPanel()) }
}
