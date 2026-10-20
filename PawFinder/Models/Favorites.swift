import Foundation

/// A saved pet. Keeps a full copy (snapshot) of the pet so favorites work offline.
struct FavoritePet: Codable, Identifiable, Hashable {
    var pet: Pet
    var addedAt: Date
    var note = ""
    /// Set when a refresh finds the pet was adopted or removed. Cleared when the user opens it.
    var statusChanged = false
    /// False when Petfinder no longer has the listing.
    var isListed = true
    /// File name of the saved photo in `FavoritesStore.photosFolder`, once downloaded.
    var localPhotoFile: String?

    var id: String { pet.id }

    /// The saved photo on the device, if there is one.
    var localPhotoURL: URL? {
        guard let localPhotoFile else { return nil }
        let url = FavoritesStore.photosFolder.appendingPathComponent(localPhotoFile)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Saved photo if we have it (works offline), otherwise the online one.
    var photoURL: URL? { localPhotoURL ?? pet.thumbnailURL }
}

/// A user-made group of favorites, like "Dogs for apartment" or "Maybe later".
struct PetCollection: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var petIDs: [String] = []   // in the user's chosen order
}
