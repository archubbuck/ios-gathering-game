import SwiftUI

enum PackSegment: String, CaseIterable {
    case inventory = "Inventory"
    case bank = "Bank"
}

/// Tab 2: the 28-slot pack and the bank, switched by segment pills.
struct PackView: View {
    @EnvironmentObject private var game: GameState
    @State private var segment: PackSegment = .inventory

    var body: some View {
        ZStack {
            TimberlineTheme.parchment.ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    Text(segment == .inventory ? "Pack" : "Bank")
                        .font(.display(30))
                        .foregroundStyle(TimberlineTheme.textOnParchment)
                    Spacer()
                    HStack(spacing: 5) {
                        CoinIcon(size: 15)
                        Text("\(game.gold) gp")
                            .font(.stat(15))
                            .foregroundStyle(TimberlineTheme.textOnParchment)
                            .monospacedDigit()
                    }
                }

                SegmentPills(
                    options: PackSegment.allCases,
                    label: { $0.rawValue },
                    selection: $segment
                )

                if segment == .inventory {
                    InventoryView()
                } else {
                    BankView()
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
}
