import Foundation

/// Builds a JSON file of everything PawFinder stores about the user, for
/// "Export my data" (a privacy requirement alongside account deletion).
@MainActor
enum DataExporter {
    private struct Export: Encodable {
        let exportedAt: Date
        let account: Account?
        let profile: AdopterProfile
        let favorites: [FavoritePet]
        let collections: [PetCollection]
        let followedShelters: [FollowedSheltersStore.FollowedShelter]
        let recentlyViewed: [Pet]
    }

    private struct Account: Encodable {
        let id: String
        let email: String?
        let displayName: String?
    }

    /// Writes the export to a temporary file and returns its URL (for ShareLink).
    static func makeFile(user: AppUser?,
                         profile: AdopterProfile,
                         favorites: FavoritesStore,
                         followed: FollowedSheltersStore,
                         recentlyViewed: RecentlyViewedStore) throws -> URL {
        let export = Export(
            exportedAt: .now,
            account: user.map { Account(id: $0.id, email: $0.email, displayName: $0.displayName) },
            profile: profile,
            favorites: favorites.favorites,
            collections: favorites.collections,
            followedShelters: followed.shelters,
            recentlyViewed: recentlyViewed.pets
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PawFinder-data.json")
        try encoder.encode(export).write(to: url, options: .atomic)
        return url
    }
}
