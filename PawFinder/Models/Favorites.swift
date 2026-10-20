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

    var id: String { pet.id }
}

/// A user-made group of favorites, like "Dogs for apartment" or "Maybe later".
struct PetCollection: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var petIDs: [String] = []   // in the user's chosen order
}
