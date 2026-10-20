import CoreSpotlight
import UniformTypeIdentifiers

/// Puts favorites into iPhone search (Spotlight), so searching "Biscuit"
/// on the home screen finds the pet. Tapping a result opens it in the app.
enum SpotlightIndexer {
    private static let domain = "favorites"

    /// Replaces everything we indexed with the current favorites.
    static func index(_ favorites: [FavoritePet]) {
        let items = favorites.map { favorite in
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = favorite.pet.name
            attributes.contentDescription = [favorite.pet.breed, favorite.pet.location]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            attributes.keywords = [favorite.pet.species, favorite.pet.breed, "adopt", "pet", "favorite"]
            attributes.thumbnailURL = favorite.localPhotoURL
            return CSSearchableItem(uniqueIdentifier: favorite.id, domainIdentifier: domain, attributeSet: attributes)
        }

        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
            guard !items.isEmpty else { return }
            index.indexSearchableItems(items) { error in
                if let error { Log.storage.error("Spotlight indexing failed: \(error.localizedDescription)") }
            }
        }
    }
}
