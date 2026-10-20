import AppIntents
import Foundation

/// Opens deep links from code that isn't a view (App Intents, notifications).
/// The app sets `handler` at launch.
@MainActor
enum AppLinks {
    static var handler: ((URL) -> Void)?

    static func open(_ link: String) {
        guard let url = URL(string: link) else { return }
        handler?(url)
    }
}

// MARK: - Siri & Shortcuts

/// Animal types Siri understands ("Show dogs in PawFinder").
enum IntentSpecies: String, AppEnum {
    case dog, cat, rabbit, bird

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Animal"
    static let caseDisplayRepresentations: [IntentSpecies: DisplayRepresentation] = [
        .dog: "Dogs", .cat: "Cats", .rabbit: "Rabbits", .bird: "Birds",
    ]
}

struct FindPetsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find adoptable pets"
    static let description = IntentDescription("Opens Discover, optionally showing one kind of animal.")
    static let openAppWhenRun = true

    @Parameter(title: "Animal")
    var species: IntentSpecies?

    @MainActor
    func perform() async throws -> some IntentResult {
        AppLinks.open("pawfinder://discover" + (species.map { "?species=\($0.rawValue)" } ?? ""))
        return .result()
    }
}

struct OpenFavoritesIntent: AppIntent {
    static let title: LocalizedStringResource = "Open my favorite pets"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppLinks.open("pawfinder://favorites")
        return .result()
    }
}

struct SheltersNearMeIntent: AppIntent {
    static let title: LocalizedStringResource = "Show shelters near me"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppLinks.open("pawfinder://map")
        return .result()
    }
}

struct OpenMessagesIntent: AppIntent {
    static let title: LocalizedStringResource = "Open my messages with shelters"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppLinks.open("pawfinder://messages")
        return .result()
    }
}

/// Shows up in the Shortcuts app and works with Siri without any setup.
struct PawFinderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: FindPetsIntent(), phrases: [
            "Find pets in \(.applicationName)",
            "Show \(\.$species) in \(.applicationName)",
            "Find adoptable \(\.$species) in \(.applicationName)",
        ], shortTitle: "Find pets", systemImageName: "pawprint")
        AppShortcut(intent: OpenFavoritesIntent(), phrases: [
            "Show my favorites in \(.applicationName)",
            "Open \(.applicationName) favorites",
        ], shortTitle: "Favorites", systemImageName: "heart")
        AppShortcut(intent: SheltersNearMeIntent(), phrases: [
            "Show shelters near me in \(.applicationName)",
            "Find shelters with \(.applicationName)",
        ], shortTitle: "Shelters near me", systemImageName: "map")
        AppShortcut(intent: OpenMessagesIntent(), phrases: [
            "Open my \(.applicationName) messages",
        ], shortTitle: "Messages", systemImageName: "bubble.left")
    }
}
