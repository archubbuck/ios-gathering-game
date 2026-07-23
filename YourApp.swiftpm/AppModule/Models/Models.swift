import Foundation

// MARK: - Reference example: Item model for the Items CRUD demo

/// Demonstrates the full-stack pattern: this Swift model mirrors the
/// `items` table schema and the JSON shape returned by `GET /api/items`.
/// Replace or extend this for your own domain models.
struct Item: Codable, Identifiable {
    let id: UUID
    var title: String
    var body: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

