import SwiftUI

/// Tab 4: tiered axe progression, Bronze through Dragon.
struct ShopView: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        ZStack {
            SylvanTheme.parchment.ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    Text("Axe Shop")
                        .font(.display(30))
                        .foregroundStyle(SylvanTheme.textOnParchment)
                    Spacer()
                    HStack(spacing: 5) {
                        CoinIcon(size: 15)
                        Text("\(game.gold) gp")
                            .font(.stat(15))
                            .foregroundStyle(SylvanTheme.textOnParchment)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(GameData.axes, id: \.tier) { axe in
                            AxeRowView(axe: axe)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

struct AxeRowView: View {
    let axe: AxeDef
    @EnvironmentObject private var game: GameState

    private enum RowState {
        case equipped, owned, buyable, tooPoor, levelLocked
    }

    private var state: RowState {
        if game.equippedAxe == axe.tier { return .equipped }
        if game.ownedAxes.contains(axe.tier) { return .owned }
        if game.level < axe.levelReq { return .levelLocked }
        if game.gold < axe.cost { return .tooPoor }
        return .buyable
    }

    var body: some View {
        HStack(spacing: 12) {
            AxeArt(tier: axe.tier)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(axe.tier.displayName) Axe")
                    .font(.display(17))
                    .foregroundStyle(SylvanTheme.textOnParchment)
                Text("Success ×\(axe.power, specifier: "%.2f")")
                    .font(.stat(12, weight: .regular))
                    .foregroundStyle(SylvanTheme.textOnParchmentSecondary)
                if axe.levelReq > 1 {
                    Text("Requires level \(axe.levelReq)")
                        .font(.stat(11, weight: .regular))
                        .foregroundStyle(
                            game.level >= axe.levelReq
                                ? SylvanTheme.textOnParchmentSecondary
                                : SylvanTheme.destructive
                        )
                }
            }

            Spacer()

            actionButton
        }
        .parchmentCard()
        .opacity(state == .levelLocked ? 0.7 : 1)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .equipped:
            Label("Equipped", systemImage: "checkmark")
                .font(.stat(13))
                .foregroundStyle(SylvanTheme.forestGreen)
        case .owned:
            Button("Equip") { game.equipAxe(axe.tier) }
                .buttonStyle(.borderedProminent)
                .tint(SylvanTheme.forestGreen)
                .font(.stat(13))
        case .buyable, .tooPoor:
            Button {
                game.buyAxe(axe.tier)
            } label: {
                HStack(spacing: 4) {
                    CoinIcon(size: 12)
                    Text("\(axe.cost)")
                        .monospacedDigit()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(state == .tooPoor ? SylvanTheme.locked : SylvanTheme.gold)
            .font(.stat(13))
            .disabled(state == .tooPoor)
        case .levelLocked:
            Label("Lv \(axe.levelReq)", systemImage: "lock.fill")
                .font(.stat(13))
                .foregroundStyle(SylvanTheme.locked)
        }
    }
}
