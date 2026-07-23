import Foundation

/// Reference ViewModel for the Items CRUD example. Demonstrates the
/// pattern every feature in this template follows:
/// 1. `@MainActor` + `ObservableObject` + `@Published` state
/// 2. Async methods call `APIClient.shared` (auth is already wired)
/// 3. Error handling with a user-facing error message string
///
/// Replace this with your own domain ViewModels.
@MainActor
final class ItemsViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await APIClient.shared.fetchItems()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func create(title: String, body: String) async {
        errorMessage = nil
        do {
            let item = try await APIClient.shared.createItem(title: title, body: body)
            items.insert(item, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: Item) async {
        errorMessage = nil
        do {
            try await APIClient.shared.deleteItem(itemId: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
