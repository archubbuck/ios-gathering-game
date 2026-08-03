import SwiftUI

/// The 28-slot OSRS-style pack grid with per-species sell/bank actions.
struct InventoryView: View {
    @EnvironmentObject private var game: GameState

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    private var speciesInPack: [(species: TreeSpecies, count: Int)] {
        TreeSpecies.allCases.compactMap { species in
            let count = game.inventory.filter { $0 == species }.count
            return count > 0 ? (species, count) : nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<GameData.inventorySlots, id: \.self) { index in
                        let contents = index < game.inventory.count ? game.inventory[index] : nil
                        slotView(contents)
                    }
                }
                .parchmentCard()

                if speciesInPack.isEmpty {
                    Text("Your pack is empty. Go chop some trees!")
                        .font(.stat(14, weight: .regular))
                        .foregroundStyle(TimberlineTheme.textOnParchmentSecondary)
                        .padding(.top, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(speciesInPack, id: \.species) { entry in
                            actionRow(species: entry.species, count: entry.count)
                        }
                        HStack(spacing: 8) {
                            Button {
                                game.sellAllLogs()
                            } label: {
                                Label("Sell all", systemImage: "dollarsign.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            Button {
                                game.depositAll()
                            } label: {
                                Label("Bank all", systemImage: "archivebox")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TimberlineTheme.forestGreen)
                        .font(.stat(14))
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func slotView(_ contents: TreeSpecies?) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(TimberlineTheme.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(TimberlineTheme.parchmentEdge, lineWidth: 1.5)
            )
            .frame(height: 44)
            .overlay {
                if let species = contents {
                    LogIcon(species: species)
                }
            }
    }

    private func actionRow(species: TreeSpecies, count: Int) -> some View {
        let price = GameData.tree(for: species).sellPrice
        return HStack(spacing: 8) {
            LogIcon(species: species)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(species.displayName) ×\(count)")
                    .font(.stat(14))
                    .foregroundStyle(TimberlineTheme.textOnParchment)
                Text("\(price) gp each")
                    .font(.stat(11, weight: .regular))
                    .foregroundStyle(TimberlineTheme.textOnParchmentSecondary)
            }
            Spacer()
            Button("Sell") { game.sell(species: species) }
                .buttonStyle(.bordered)
                .tint(TimberlineTheme.gold)
            Button("Bank") { game.deposit(species: species) }
                .buttonStyle(.bordered)
                .tint(TimberlineTheme.forestGreen)
        }
        .font(.stat(13))
        .parchmentCard()
    }
}
