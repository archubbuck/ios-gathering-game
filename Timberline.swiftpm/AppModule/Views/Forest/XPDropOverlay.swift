import SwiftUI

/// Floating "+25 XP" text that rises and fades above the active tree.
/// A new `XPDrop.id` recreates the view, restarting the animation.
struct XPDropOverlay: View {
    let drop: XPDrop

    @State private var risen = false

    var body: some View {
        Text("+\(Int(drop.amount)) XP")
            .font(.stat(16, weight: .bold))
            .foregroundStyle(TimberlineTheme.gold)
            .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
            .offset(y: risen ? -52 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) {
                    risen = true
                }
            }
            .allowsHitTesting(false)
    }
}
