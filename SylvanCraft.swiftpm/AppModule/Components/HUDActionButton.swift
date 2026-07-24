import SwiftUI

/// Large frosted rounded-square shortcut button for the in-scene forest
/// HUD (Inventory, Skills): a big icon over a bold white label.
struct HUDActionButton<Icon: View>: View {
    let title: String
    @ViewBuilder let icon: Icon
    let action: () -> Void

    init(
        title: String,
        @ViewBuilder icon: () -> Icon,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon()
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                icon
                    .frame(height: 34)
                Text(title)
                    .font(.stat(12, weight: .heavy))
                    .hudSceneLabel()
            }
            .frame(width: 74, height: 74)
            .hudPanel(cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }
}
