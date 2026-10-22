import Foundation

/// A pet as the app uses it. Listings stored in Firestore are converted into
/// this (see ListingMapper), so screens never deal with raw documents.
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
    var distance: Double?        // miles, only when searching near a location
    let shelterID: String        // the lister's user ID (the person or group who posted the pet)
    let goodWithKids: Bool?      // nil = unknown
    let goodWithDogs: Bool?
    let goodWithCats: Bool?
    let houseTrained: Bool
    let specialNeeds: Bool
    let tags: [String]           // temperament, e.g. "Playful"
    let publishedAt: Date?
    let webURL: URL?

    // Everything below is optional with a default, so favorites saved by
    // older versions of the app still decode.
    var primaryBreed: String? = nil   // "Beagle", used to find similar pets
    var contactEmail: String? = nil
    var contactPhone: String? = nil
    var status: String? = nil         // "adoptable", "pending", "adopted"
    var coat: String? = nil           // "Short", "Medium", "Long", "Wire", "Hairless", "Curly"

    // Details a lister fills in.
    var ageDetail: String? = nil      // "2 years 3 months"
    var colors: String? = nil         // "Black and white"
    var weight: String? = nil         // "12 kg"
    var vaccinated: Bool? = nil
    var spayedNeutered: Bool? = nil
    var microchipped: Bool? = nil
    var specialNeedsNotes: String? = nil
    var healthNotes: String? = nil
    var adoptionFee: Double? = nil    // 0 or nil = free
    var listedBy: String? = nil       // the lister's name, e.g. "Sunny Paws Rescue"
    var videoLink: URL? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil

    // Fostering. A pet either needs a foster, or is in foster care with someone.
    var fosterNeeded: Bool? = nil
    var fosterReason: String? = nil
    var fosterDuration: String? = nil     // "A few weeks"
    var fosterByID: String? = nil
    var fosterByName: String? = nil       // the volunteer's public name only

    var needsFoster: Bool { fosterNeeded == true && !isAdopted }
    var isInFosterCare: Bool { !(fosterByName ?? "").isEmpty && !isAdopted }

    var isAdopted: Bool { status?.lowercased() == "adopted" }
    var isPending: Bool { status?.lowercased() == "pending" }

    /// "Young · Male · Medium", for list rows.
    var summary: String {
        [age, gender, size].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// "Free" or "$150".
    var feeText: String {
        guard let adoptionFee, adoptionFee > 0 else { return "Free" }
        return adoptionFee.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD").precision(.fractionLength(0...2)))
    }
}

/// One page of results, plus whether more pages exist.
struct PetPage {
    let pets: [Pet]
    let currentPage: Int
    let totalPages: Int

    var hasMore: Bool { currentPage < totalPages }
}

extension Pet {
    /// A stand-in used by loading skeletons and SwiftUI previews. It never
    /// appears as real data.
    static let placeholder = Pet(
        id: "placeholder", name: "Loading name", species: "Dog", breed: "Loading breed", age: "Young",
        gender: "Female", size: "Medium", description: nil, photoURLs: [], thumbnailURL: nil,
        location: "City, ST", distance: nil, shelterID: "placeholder", goodWithKids: nil, goodWithDogs: nil,
        goodWithCats: nil, houseTrained: true, specialNeeds: false, tags: [], publishedAt: nil, webURL: nil
    )
}
