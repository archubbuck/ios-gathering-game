import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss

    @State private var confirmingReset = false
    @State private var confirmingResetAgain = false

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                }

                Section("Feedback") {
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                }

                Section {
                    Button("Reset all progress", role: .destructive) {
                        confirmingReset = true
                    }
                } header: {
                    Text("Danger zone")
                } footer: {
                    Text("Erases your level, gold, logs, axes, and achievements. This cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Reset all progress?",
                isPresented: $confirmingReset,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    confirmingResetAgain = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your entire woodcutting career will be erased.")
            }
            .alert("Are you absolutely sure?", isPresented: $confirmingResetAgain) {
                Button("Erase everything", role: .destructive) {
                    game.resetSave()
                    dismiss()
                }
                Button("Keep my progress", role: .cancel) {}
            } message: {
                Text("Level \(game.level), \(game.gold) gp, and \(game.stats.totalLogs) logs chopped will be lost forever.")
            }
        }
    }
}
