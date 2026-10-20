import Foundation

/// Everything the user can search and filter by on Discover.
struct PetFilters: Codable, Equatable {
    var name = ""                    // search box text
    var species: Species?
    var breed: String?
    var ages: Set<Age> = []
    var sizes: Set<Size> = []
    var gender: Gender?
    var goodWithKids = false
    var goodWithDogs = false
    var goodWithCats = false
    var houseTrained = false
    var location = ""                // US/Canada ZIP or "City, ST"
    var distance = 50                // miles, only used with a location
    var sort: Sort = .newest

    enum Species: String, Codable, CaseIterable {
        case dog = "Dog", cat = "Cat", rabbit = "Rabbit", bird = "Bird"
    }

    enum Age: String, Codable, CaseIterable {
        case baby = "Baby", young = "Young", adult = "Adult", senior = "Senior"
    }

    enum Size: String, Codable, CaseIterable {
        case small = "Small", medium = "Medium", large = "Large", xlarge = "Extra Large"

        var apiValue: String { self == .xlarge ? "xlarge" : rawValue.lowercased() }
    }

    enum Gender: String, Codable, CaseIterable {
        case male = "Male", female = "Female"
    }

    enum Sort: String, Codable, CaseIterable {
        case newest = "Newest"
        case longestWaiting = "Longest waiting"
        case nearest = "Nearest"
        case random = "Random"

        var apiValue: String {
            switch self {
            case .newest: "recent"
            case .longestWaiting: "-recent"
            case .nearest: "distance"
            case .random: "random"
            }
        }
    }

    /// Filter values without the search text. Used for the badge and "Clear".
    var withoutName: PetFilters {
        var copy = self
        copy.name = ""
        return copy
    }

    /// True when nothing is narrowing the results (search text or filters).
    var isDefault: Bool { self == PetFilters() }

    /// How many filters are on, for the badge on the filter button.
    var activeCount: Int {
        var count = ages.count + sizes.count
        if species != nil { count += 1 }
        if breed != nil { count += 1 }
        if gender != nil { count += 1 }
        count += [goodWithKids, goodWithDogs, goodWithCats, houseTrained].filter { $0 }.count
        if !location.isEmpty { count += 1 }
        return count
    }

    /// Petfinder query parameters (https://www.petfinder.com/developers/v2/docs/#get-animals).
    var queryItems: [String: String] {
        var query = ["sort": sort.apiValue]
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty { query["name"] = trimmedName }
        if let species { query["type"] = species.rawValue }
        if let breed { query["breed"] = breed }
        if !ages.isEmpty { query["age"] = ages.map { $0.rawValue.lowercased() }.sorted().joined(separator: ",") }
        if !sizes.isEmpty { query["size"] = sizes.map(\.apiValue).sorted().joined(separator: ",") }
        if let gender { query["gender"] = gender.rawValue.lowercased() }
        if goodWithKids { query["good_with_children"] = "true" }
        if goodWithDogs { query["good_with_dogs"] = "true" }
        if goodWithCats { query["good_with_cats"] = "true" }
        if houseTrained { query["house_trained"] = "true" }

        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        if trimmedLocation.isEmpty {
            // "Nearest" needs a location; fall back to newest.
            if sort == .nearest { query["sort"] = Sort.newest.apiValue }
        } else {
            query["location"] = trimmedLocation
            query["distance"] = String(distance)
        }
        return query
    }
}
