import Foundation

// MARK: - Auth

struct AppleAuthRequestBody: Encodable {
    let identityToken: String

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
    }
}

struct DeviceAuthRequestBody: Encodable {
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
    }
}

struct AuthResponse: Decodable {
    let accessToken: String
    let userId: UUID
    let isNewUser: Bool

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userId = "user_id"
        case isNewUser = "is_new_user"
    }
}

// MARK: - Push / device registration

struct RegisterDeviceRequestBody: Encodable {
    let token: String
    let environment: String
    let timezone: String
}

// MARK: - Analytics

struct AnalyticsEventPayload: Codable {
    let eventType: String
    let payload: [String: String]
    let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case payload
        case occurredAt = "occurred_at"
    }
}

struct AnalyticsEventsRequestBody: Encodable {
    let events: [AnalyticsEventPayload]
}

struct AnalyticsEventsResponse: Decodable {
    let accepted: Int
}

// MARK: - Items CRUD (reference example)

struct CreateItemRequestBody: Encodable {
    let title: String
    let body: String
}

struct PatchItemRequestBody: Encodable {
    var title: String?
    var body: String?
}

struct ItemsListResponse: Decodable {
    let items: [Item]
}

// MARK: - Helpers

/// Used for POST requests with no meaningful request body.
struct EmptyEncodable: Encodable {}

/// Used for DELETE responses with no body.
struct EmptyDecodable: Decodable {}

