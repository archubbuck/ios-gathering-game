import SwiftUI

/// Reference Items list view demonstrating the full-stack pattern:
/// SwiftUI → APIClient → Vercel API → Neon Postgres, all auth-protected.
/// Replace this with your own feature views.
struct ItemsView: View {
    @StateObject private var viewModel = ItemsViewModel()
    @State private var isShowingAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "No items yet",
                        systemImage: "tray",
                        description: Text("Tap + to create your first item.")
                    )
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                if !item.body.isEmpty {
                                    Text(item.body)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                Task { await viewModel.delete(viewModel.items[index]) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Items")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddItemSheet(viewModel: viewModel, isPresented: $isShowingAddSheet)
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }
}

private struct AddItemSheet: View {
    @ObservedObject var viewModel: ItemsViewModel
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var bodyText = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Body (optional)", text: $bodyText, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.create(title: title, body: bodyText)
                            isPresented = false
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
