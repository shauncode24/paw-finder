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
    var location = ""                // US/Canada ZIP, "City, ST", or "lat,long"
    var locationName: String?        // shown instead of `location`, e.g. "Current location"
    var distance = 50                // miles, only used with a location
    var sort: Sort = .newest
    var shelterID: String?           // only this shelter's pets (shelter profile)

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

    enum Coat: String, Codable, CaseIterable {
        case short = "Short", medium = "Medium", long = "Long", wire = "Wire", hairless = "Hairless", curly = "Curly"
    }

    /// How long the pet has been listed (Petfinder's `after` / `before` dates).
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

        var apiValue: String {
            switch self {
            case .newest: "recent"
            case .longestWaiting: "-recent"
            case .nearest: "distance"
            case .random: "random"
            }
        }
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

    /// Petfinder query parameters (https://www.petfinder.com/developers/v2/docs/#get-animals).
    var queryItems: [String: String] {
        var query = ["sort": sort.apiValue]
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty { query["name"] = trimmedName }
        if let species { query["type"] = species.rawValue }
        if let breed { query["breed"] = breed }
        if let shelterID { query["organization"] = shelterID }
        if !ages.isEmpty { query["age"] = ages.map { $0.rawValue.lowercased() }.sorted().joined(separator: ",") }
        if !sizes.isEmpty { query["size"] = sizes.map(\.apiValue).sorted().joined(separator: ",") }
        if let gender { query["gender"] = gender.rawValue.lowercased() }
        if goodWithKids { query["good_with_children"] = "true" }
        if goodWithDogs { query["good_with_dogs"] = "true" }
        if goodWithCats { query["good_with_cats"] = "true" }
        if houseTrained { query["house_trained"] = "true" }
        if specialNeeds { query["special_needs"] = "true" }
        if !coats.isEmpty { query["coat"] = coats.map { $0.rawValue.lowercased() }.sorted().joined(separator: ",") }
        if let dateFilter = listed.dateFilter {
            // Rounded to the hour so the offline cache key stays the same for a while.
            let hour = Calendar.current.dateInterval(of: .hour, for: dateFilter.date)?.start ?? dateFilter.date
            query[dateFilter.key] = Self.apiDateFormatter.string(from: hour)
        }

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

    /// Petfinder wants dates like "2026-10-07T19:00:00+00:00".
    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssxxxxx"
        return formatter
    }()
}
