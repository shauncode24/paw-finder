import Foundation

/// Reads API keys from Secrets.plist (gitignored).
enum Secrets {
    static var petfinderAPIKey: String { value(for: "PETFINDER_API_KEY") }
    static var petfinderAPISecret: String { value(for: "PETFINDER_API_SECRET") }

    /// True once both Petfinder keys are filled in.
    static var hasPetfinderKeys: Bool {
        !petfinderAPIKey.isEmpty && !petfinderAPISecret.isEmpty
    }

    private static let values: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return dict
    }()

    private static func value(for key: String) -> String {
        (values[key] as? String) ?? ""
    }
}
