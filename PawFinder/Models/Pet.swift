import Foundation

/// A pet as the app uses it. API responses are converted into this
/// (see PetfinderModels.swift), so screens never deal with raw JSON.
struct Pet: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let species: String          // "Dog", "Cat", ...
    let breed: String            // "Beagle", "Beagle / Labrador Retriever Mix"
    let age: String              // "Baby", "Young", "Adult", "Senior"
    let gender: String           // "Male", "Female", "Unknown"
    let size: String             // "Small", "Medium", "Large", "Extra Large"
    let description: String?
    let photoURLs: [URL]         // large photos, for the detail screen
    let thumbnailURL: URL?       // small photo, for grids and rails
    let location: String         // "Austin, TX"
    let distance: Double?        // miles, only when searching near a location
    let shelterID: String
    let goodWithKids: Bool?      // nil = unknown
    let goodWithDogs: Bool?
    let goodWithCats: Bool?
    let houseTrained: Bool
    let specialNeeds: Bool
    let tags: [String]
    let publishedAt: Date?
    let webURL: URL?             // the listing on petfinder.com

    // Added in Phase 3. Optional with defaults so older saved data still decodes.
    var primaryBreed: String? = nil   // "Beagle", used to find similar pets
    var contactEmail: String? = nil
    var contactPhone: String? = nil

    /// "Young · Male · Medium", for list rows.
    var summary: String {
        [age, gender, size].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// One page of results, plus whether more pages exist.
struct PetPage {
    let pets: [Pet]
    let currentPage: Int
    let totalPages: Int

    var hasMore: Bool { currentPage < totalPages }
}
