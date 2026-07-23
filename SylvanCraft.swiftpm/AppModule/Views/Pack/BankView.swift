import SwiftUI

/// High-capacity stacked storage with withdraw and sell-from-bank.
struct BankView: View {
    @EnvironmentObject private var game: GameState
    @State private var selected: TreeSpecies?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if game.bank.isEmpty {
                    Text("Your bank vault is empty.\nBank logs from your pack to store them safely.")
                        .font(.stat(14, weight: .regular))
                        .foregroundStyle(SylvanTheme.textOnParchmentSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 30)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(game.bank) { stack in
                            stackCard(stack)
                        }
                    }

                    if let species = selected,
                        let stack = game.bank.first(where: { $0.species == species })
                    {
                        withdrawPanel(species: species, stack: stack)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .onChange(of: game.bank.count) { _ in
            if let species = selected, !game.bank.contains(where: { $0.species == species }) {
                selected = nil
            }
        }
    }

    private func stackCard(_ stack: ItemStack) -> some View {
        Button {
            selected = selected == stack.species ? nil : stack.species
        } label: {
            VStack(spacing: 6) {
                LogIcon(species: stack.species)
                Text(stack.species.displayName)
                    .font(.stat(12))
                    .foregroundStyle(SylvanTheme.textOnParchment)
                Text("×\(stack.count)")
                    .font(.stat(13))
                    .foregroundStyle(SylvanTheme.textOnParchmentSecondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SylvanTheme.parchmentLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                selected == stack.species
                                    ? SylvanTheme.forestGreen
                                    : SylvanTheme.parchmentEdge,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func withdrawPanel(species: TreeSpecies, stack: ItemStack) -> some View {
        let price = GameData.tree(for: species).sellPrice
        return VStack(spacing: 10) {
            Text("\(species.displayName) logs ×\(stack.count)")
                .font(.stat(15))
                .foregroundStyle(SylvanTheme.textOnParchment)
            HStack(spacing: 8) {
                Button("Take 1") { game.withdraw(species: species, count: 1) }
                Button("Take 5") { game.withdraw(species: species, count: 5) }
                Button("Take all") { game.withdraw(species: species, count: stack.count) }
            }
            .buttonStyle(.bordered)
            .tint(SylvanTheme.forestGreen)
            Button {
                game.sellFromBank(species: species, count: stack.count)
            } label: {
                HStack(spacing: 5) {
                    CoinIcon(size: 13)
                    Text("Sell all (\(stack.count * price) gp)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(SylvanTheme.gold)
        }
        .font(.stat(13))
        .parchmentCard()
    }
}
