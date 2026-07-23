import Foundation

extension APIClient {
    // MARK: - Auth

    func signInWithApple(identityToken: String) async throws -> AuthResponse {
        try await request(
            "/auth/apple",
            method: "POST",
            body: AppleAuthRequestBody(identityToken: identityToken)
        )
    }

    func signInWithDevice(deviceId: String) async throws -> AuthResponse {
        try await request(
            "/auth/device",
            method: "POST",
            body: DeviceAuthRequestBody(deviceId: deviceId)
        )
    }

    // MARK: - Push / device registration

    func registerDevice(token: String, environment: String, timezone: String) async throws {
        let _: EmptyDecodable = try await request(
            "/devices",
            method: "POST",
            body: RegisterDeviceRequestBody(token: token, environment: environment, timezone: timezone)
        )
    }

    // MARK: - Analytics

    func sendAnalyticsEvents(_ events: [AnalyticsEventPayload]) async throws {
        let _: AnalyticsEventsResponse = try await request(
            "/analytics/events",
            method: "POST",
            body: AnalyticsEventsRequestBody(events: events)
        )
    }

    // MARK: - Items CRUD (reference example — replace with your own domain)

    func fetchItems() async throws -> [Item] {
        let response: ItemsListResponse = try await request("/items")
        return response.items
    }

    func createItem(title: String, body: String) async throws -> Item {
        try await request("/items", method: "POST", body: CreateItemRequestBody(title: title, body: body))
    }

    func fetchItem(itemId: UUID) async throws -> Item {
        try await request("/items/\(itemId.uuidString)")
    }

    func updateItem(itemId: UUID, title: String?, body: String?) async throws -> Item {
        try await request(
            "/items/\(itemId.uuidString)",
            method: "PATCH",
            body: PatchItemRequestBody(title: title, body: body)
        )
    }

    func deleteItem(itemId: UUID) async throws {
        let _: EmptyDecodable = try await request("/items/\(itemId.uuidString)", method: "DELETE")
    }
}

