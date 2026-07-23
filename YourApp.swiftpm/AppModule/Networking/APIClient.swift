import Foundation

/// Talks to the API. The base URL should point at your Vercel deployment.
/// The `/v1` path prefix is handled by `next.config.js` rewrites.
final class APIClient {
    static let shared = APIClient()

    /// Supplies the current bearer token for every request. Set by
    /// `SessionStore` once a user is signed in; `nil` while signed out.
    var tokenProvider: (() -> String?)?

    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL = URL(string: "https://your-project.vercel.app/v1")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = APIClient.iso8601WithFractionalSeconds.date(from: raw) {
                return date
            }
            if let date = APIClient.iso8601.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO 8601 date string, got \(raw)"
            )
        }
    }

    private static let iso8601 = ISO8601DateFormatter()
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - No-body requests (GET, DELETE without a payload)

    func request<Response: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem] = []
    ) async throws -> Response {
        let request = try buildRequest(path: path, method: method, query: query, bodyData: nil)
        return try await perform(request)
    }

    // MARK: - Requests with an encodable JSON body

    func request<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        body: Body,
        query: [URLQueryItem] = []
    ) async throws -> Response {
        let bodyData = try encoder.encode(body)
        let request = try buildRequest(path: path, method: method, query: query, bodyData: bodyData)
        return try await perform(request)
    }

    private func buildRequest(
        path: String,
        method: String,
        query: [URLQueryItem],
        bodyData: Data?
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = tokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyData
        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            let message = (try? decoder.decode(APIErrorBody.self, from: data))?.error
            throw APIError.server(status: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}

/// A response type for endpoints whose success body carries no fields the
/// client needs to read (e.g. `{ "removed": true }`).
struct EmptyDecodable: Decodable {}
