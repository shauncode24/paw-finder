import Foundation

/// Talks to the Petfinder v2 API (https://www.petfinder.com/developers/v2/docs/).
///
/// Petfinder uses OAuth: we trade the API key + secret for an access token
/// that lasts about an hour, then send it with every request. This actor
/// keeps the token and gets a new one when it expires.
actor PetfinderClient {
    private let baseURL = "https://api.petfinder.com/v2"
    private let apiKey: String
    private let apiSecret: String
    private let session: URLSession

    private var token: String?
    private var tokenExpiry = Date.distantPast

    init(apiKey: String, apiSecret: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.session = session
    }

    /// GET a path like "animals" and decode the JSON into `T`.
    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: "\(baseURL)/\(path)")
        components?.queryItems = query.isEmpty ? nil : query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else { throw APIError.unknown }

        var (data, status) = try await send(url: url, token: try await validToken())

        // The token can expire early; refresh once and retry.
        if status == 401 {
            token = nil
            (data, status) = try await send(url: url, token: try await validToken())
        }

        try check(status)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            print("Petfinder decoding error for \(path): \(error)")
            throw APIError.decoding
        }
    }

    // MARK: - Private

    private func send(url: URL, token: String) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    private func validToken() async throws -> String {
        if let token, Date() < tokenExpiry {
            return token
        }

        guard let tokenURL = URL(string: "\(baseURL)/oauth2/token") else { throw APIError.unknown }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "client_id", value: apiKey),
            URLQueryItem(name: "client_secret", value: apiSecret),
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, status) = try await perform(request)
        if status == 400 || status == 401 { throw APIError.unauthorized }
        try check(status)

        guard let response = try? Self.decoder.decode(TokenResponse.self, from: data) else {
            throw APIError.decoding
        }
        token = response.accessToken
        // Refresh a minute early so a request never goes out with a just-expired token.
        tokenExpiry = Date().addingTimeInterval(TimeInterval(response.expiresIn - 60))
        return response.accessToken
    }

    private func perform(_ request: URLRequest) async throws -> (Data, Int) {
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (data, status)
        } catch let error as URLError
            where [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(error.code) {
            throw APIError.offline
        } catch {
            throw APIError.unknown
        }
    }

    private func check(_ status: Int) throws {
        switch status {
        case 200..<300: return
        case 400: throw APIError.badRequest
        case 401, 403: throw APIError.unauthorized
        case 404: throw APIError.notFound
        case 429: throw APIError.rateLimited
        default: throw APIError.server(statusCode: status)
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private struct TokenResponse: Decodable {
        let accessToken: String
        let expiresIn: Int
    }
}
