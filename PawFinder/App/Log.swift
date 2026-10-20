import OSLog

/// App logging. Shows up in Xcode's console and in the Console app,
/// filterable by category. Use instead of `print`.
///
///     Log.network.error("Request failed: \(error)")
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "PawFinder"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let location = Logger(subsystem: subsystem, category: "location")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
}
