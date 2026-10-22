import Foundation

/// A Discover search the user saved, optionally with alerts for new matches.
struct SavedSearch: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var filters: PetFilters
    var alertsOn = true
    var createdAt = Date.now
    /// Newest listing already counted, so only newer pets are "new".
    var lastSeenListing = Date.now
    /// New matches since the user last opened this search.
    var newMatchCount = 0

    /// A short name built from the filters, e.g. "Senior Cat near 78702".
    static func suggestedName(for filters: PetFilters) -> String {
        var parts: [String] = []
        if !filters.name.isEmpty { parts.append("\"\(filters.name)\"") }
        if filters.ages.count == 1, let age = filters.ages.first { parts.append(age.rawValue) }
        if let breed = filters.breed {
            parts.append(breed)
        } else if let species = filters.species {
            parts.append(species.rawValue)
        } else {
            parts.append("Pets")
        }
        if filters.goodWithKids { parts.append("good with kids") }
        if !filters.location.isEmpty { parts.append("near \(filters.locationLabel)") }
        return parts.joined(separator: " ")
    }
}

/// Which notifications the user wants, and when to keep quiet.
struct NotificationPreferences: Codable, Equatable {
    enum Category: String, Codable, CaseIterable {
        case favorites = "Favorite pet updates"
        case shelters = "New pets at followed shelters"
        case savedSearches = "Saved search matches"
        case applications = "Application updates"
        case messages = "Messages from shelters"
        case journey = "Adoption journey check-ins"

        var icon: String {
            switch self {
            case .favorites: "heart"
            case .shelters: "star"
            case .savedSearches: "magnifyingglass"
            case .applications: "doc.text"
            case .messages: "bubble.left"
            case .journey: "heart.text.square"
            }
        }
    }

    var disabled: Set<Category> = []
    var quietHoursOn = false
    var quietStart = 22 * 60     // minutes after midnight (10:00 PM)
    var quietEnd = 7 * 60        // 7:00 AM

    func isOn(_ category: Category) -> Bool { !disabled.contains(category) }

    /// True if `date` falls inside quiet hours (which may cross midnight).
    func isQuiet(at date: Date) -> Bool {
        guard quietHoursOn, quietStart != quietEnd else { return false }
        let minutes = Self.minutes(of: date)
        return quietStart < quietEnd
            ? (quietStart..<quietEnd).contains(minutes)
            : minutes >= quietStart || minutes < quietEnd
    }

    /// Moves a delivery time out of quiet hours, to when they end.
    func deliveryDate(for date: Date) -> Date {
        guard isQuiet(at: date) else { return date }
        let calendar = Calendar.current
        var end = calendar.startOfDay(for: date).addingTimeInterval(TimeInterval(quietEnd * 60))
        if end <= date { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }
        return end
    }

    private static func minutes(of date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    // MARK: - Saving

    private static let key = "notificationPreferences"

    static var current: NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(NotificationPreferences.self, from: data) else {
            return NotificationPreferences()
        }
        return saved
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
