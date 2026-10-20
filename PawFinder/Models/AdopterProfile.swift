import Foundation

/// The user's profile and lifestyle answers. The answers will drive the
/// compatibility score in Phase 12.
struct AdopterProfile: Codable, Equatable {
    var displayName = ""
    var homeType: HomeType?
    var kids: KidsAtHome?
    var otherPets: Set<OtherPet> = []
    var experience: Experience?
    var schedule: Schedule?
    var activity: ActivityLevel?
    var preferredSpecies: Set<PetFilters.Species> = []
    var preferredSizes: Set<PetFilters.Size> = []

    enum HomeType: String, Codable, CaseIterable {
        case apartment = "Apartment"
        case houseNoYard = "House, no yard"
        case houseWithYard = "House with a yard"
        case farm = "Farm or lots of land"
    }

    enum KidsAtHome: String, Codable, CaseIterable {
        case none = "No kids"
        case young = "Kids under 6"
        case school = "Kids 6–12"
        case teens = "Teens"
    }

    enum OtherPet: String, Codable, CaseIterable {
        case dogs = "Dogs"
        case cats = "Cats"
        case other = "Other pets"
    }

    enum Experience: String, Codable, CaseIterable {
        case firstTime = "First-time owner"
        case some = "Had pets before"
        case experienced = "Very experienced"
    }

    enum Schedule: String, Codable, CaseIterable {
        case mostlyHome = "Home most of the day"
        case partTime = "Out part of the day"
        case awayAllDay = "Out all day"
    }

    enum ActivityLevel: String, Codable, CaseIterable {
        case relaxed = "Relaxed"
        case moderate = "Moderately active"
        case veryActive = "Very active"
    }

    /// Questions answered so far (out of `questionCount`).
    var answeredCount: Int {
        [homeType != nil, kids != nil, experience != nil, schedule != nil, activity != nil].filter { $0 }.count
    }

    static let questionCount = 5

    var isQuestionnaireComplete: Bool { answeredCount == Self.questionCount }

    /// "House with a yard · Kids 6–12 · Very active", for the profile screen.
    var lifestyleSummary: String {
        [homeType?.rawValue, kids?.rawValue, activity?.rawValue].compactMap { $0 }.joined(separator: " · ")
    }
}
