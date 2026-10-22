import Foundation

/// Everything the user can search and filter by on Discover.
struct PetFilters: Codable, Hashable {
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
    var specialNeeds = false
    var coats: Set<Coat> = []
    var listed: Listed = .any
    var location = ""                // ZIP/postcode, "City, ST", or "lat,long"
    var locationName: String?        // shown instead of `location`, e.g. "Current location"
    var distance = 50                // miles, only used with a location
    var sort: Sort = .newest
    var shelterID: String?           // only this lister's pets (lister profile)

    enum Species: String, Codable, CaseIterable {
        case dog = "Dog", cat = "Cat", rabbit = "Rabbit", bird = "Bird"
    }

    enum Age: String, Codable, CaseIterable {
        case baby = "Baby", young = "Young", adult = "Adult", senior = "Senior"
    }

    enum Size: String, Codable, CaseIterable {
        case small = "Small", medium = "Medium", large = "Large", xlarge = "Extra Large"
    }

    enum Gender: String, Codable, CaseIterable {
        case male = "Male", female = "Female"
    }

    enum Coat: String, Codable, CaseIterable {
        case short = "Short", medium = "Medium", long = "Long", wire = "Wire", hairless = "Hairless", curly = "Curly"
    }

    /// How long the pet has been listed.
    enum Listed: String, Codable, CaseIterable {
        case any = "Any time"
        case today = "New today"
        case thisWeek = "This week"
        case threeMonths = "Waiting 3+ months"
        case oneYear = "Waiting 1+ year"

        /// (parameter name, cutoff date), or nil for "Any time".
        var dateFilter: (key: String, date: Date)? {
            let calendar = Calendar.current
            let now = Date.now
            switch self {
            case .any: return nil
            case .today: return ("after", calendar.startOfDay(for: now))
            case .thisWeek: return ("after", calendar.date(byAdding: .day, value: -7, to: now) ?? now)
            case .threeMonths: return ("before", calendar.date(byAdding: .month, value: -3, to: now) ?? now)
            case .oneYear: return ("before", calendar.date(byAdding: .year, value: -1, to: now) ?? now)
            }
        }
    }

    enum Sort: String, Codable, CaseIterable {
        case newest = "Newest"
        case longestWaiting = "Longest waiting"
        case nearest = "Nearest"
        case random = "Random"
    }

    /// What to show for the location, e.g. "Current location" or "Austin, TX".
    var locationLabel: String { locationName ?? location }

    /// Filter values without the search text. Used for the badge and "Clear".
    var withoutName: PetFilters {
        var copy = self
        copy.name = ""
        return copy
    }

    /// True when nothing is narrowing the results (search text or filters).
    var isDefault: Bool { self == PetFilters() }

    /// True when the only thing set is a location (rails still make sense then).
    var isBrowsing: Bool {
        var copy = self
        copy.location = ""
        copy.locationName = nil
        copy.distance = PetFilters().distance
        return copy.isDefault
    }

    /// How many filters are on, for the badge on the filter button.
    var activeCount: Int {
        var count = ages.count + sizes.count
        if species != nil { count += 1 }
        if breed != nil { count += 1 }
        if gender != nil { count += 1 }
        count += coats.count
        count += [goodWithKids, goodWithDogs, goodWithCats, houseTrained, specialNeeds].filter { $0 }.count
        if listed != .any { count += 1 }
        if !location.isEmpty { count += 1 }
        return count
    }
}
