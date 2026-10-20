import Foundation

/// Errors from the network layer, each with a message that's OK to show users.
enum APIError: LocalizedError {
    case missingKeys
    case offline
    case badRequest
    case unauthorized
    case notFound
    case rateLimited
    case server(statusCode: Int)
    case decoding
    case unknown

    var errorDescription: String? {
        switch self {
        case .missingKeys: "Add your Petfinder keys to Secrets.plist."
        case .offline: "You're offline. Check your connection and try again."
        case .badRequest: "Some filters aren't valid. Check the location (use a US ZIP code or \"City, ST\")."
        case .unauthorized: "Couldn't sign in to Petfinder. Check your API key and secret."
        case .notFound: "This pet couldn't be found. It may have been adopted."
        case .rateLimited: "Too many requests. Please wait a moment and try again."
        case .server(let code): "The server had a problem (\(code)). Please try again."
        case .decoding: "We got an unexpected response. Please try again."
        case .unknown: "Something went wrong. Please try again."
        }
    }
}
