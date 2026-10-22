import Foundation

/// Errors from loading and saving shared data (listings, chats, applications),
/// each with a message that's OK to show users.
enum APIError: LocalizedError {
    case notConfigured          // Firebase isn't set up (no GoogleService-Info.plist)
    case notSignedIn
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
        case .notConfigured: "PawFinder isn't connected to its backend yet. See docs/SETUP.md to set up Firebase."
        case .notSignedIn: "Please sign in to do that."
        case .offline: "You're offline. Check your connection and try again."
        case .badRequest: "That didn't work. Check the location (a ZIP code or \"City, ST\") and your filters."
        case .unauthorized: "You don't have permission to do that. Try signing in again."
        case .notFound: "This pet couldn't be found. It may have been adopted or removed."
        case .rateLimited: "Too many requests. Please wait a moment and try again."
        case .server(let code): "The server had a problem (\(code)). Please try again."
        case .decoding: "We got an unexpected response. Please try again."
        case .unknown: "Something went wrong. Please try again."
        }
    }
}
