import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case network(Error)
    case unauthorized
    case server(status: Int, message: String?)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .network(let error):
            return error.localizedDescription
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .server(_, let message):
            return message ?? "Something went wrong. Please try again."
        case .decoding:
            return "Couldn't read the server's response."
        }
    }
}

struct APIErrorBody: Decodable {
    let error: String
}
