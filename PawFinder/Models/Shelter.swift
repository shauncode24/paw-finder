import Foundation

/// The shelter or rescue group that lists a pet ("organization" in Petfinder).
struct Shelter: Identifiable, Hashable {
    let id: String
    let name: String
    let email: String?
    let phone: String?
    let address: String          // "7201 Levander Loop, Austin, TX 78702"
    let website: URL?
    let petfinderURL: URL?

    // Added in Phase 5. Defaults keep older call sites working.
    var city: String? = nil
    var state: String? = nil
    var postcode: String? = nil
    var missionStatement: String? = nil
    /// Free-text opening hours per weekday, e.g. ["monday": "9:00 AM - 5:00 PM"].
    var hours: [String: String] = [:]
    var photoURLs: [URL] = []
    var distance: Double? = nil  // miles, only when searching near a location
    var adoptionPolicy: String? = nil
    var adoptionURL: URL? = nil

    /// What to send to the geocoder: the street address, or at least city/ZIP.
    var geocodeQuery: String {
        if !address.isEmpty { return address }
        return [city, state, postcode].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var cityState: String {
        [city, state].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// One page of shelters from a location search.
struct ShelterPage {
    let shelters: [Shelter]
    let currentPage: Int
    let totalPages: Int
    var isSample = false

    var hasMore: Bool { currentPage < totalPages }
}

// MARK: - Opening hours

extension Shelter {
    enum OpenStatus: Equatable {
        case open(closes: String)   // "Open · closes 5:00 PM"
        case closed
        case unknown                // no hours, or hours we can't read

        var label: String? {
            switch self {
            case .open(let closes): "Open now · closes \(closes)"
            case .closed: "Closed now"
            case .unknown: nil
            }
        }
    }

    static let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    /// Today's weekday key, e.g. "monday".
    static func weekdayKey(for date: Date = .now) -> String {
        weekdays[Calendar.current.component(.weekday, from: date) - 1]
    }

    /// Works out "open now" from the free-text hours shelters type in.
    /// Understands things like "9-5", "9:00 AM - 5:00 PM", "10am-6pm", "Closed".
    func openStatus(at date: Date = .now) -> OpenStatus {
        guard let text = hours[Self.weekdayKey(for: date)], !text.isEmpty else { return .unknown }
        let lower = text.lowercased()
        if lower.contains("closed") { return .closed }
        if lower.contains("24 hours") { return .open(closes: "midnight") }
        guard let (opens, closes) = Self.parseHours(lower) else { return .unknown }

        let now = Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
        return (opens..<closes).contains(now) ? .open(closes: Self.timeText(closes)) : .closed
    }

    /// Returns opening and closing time as minutes after midnight.
    static func parseHours(_ text: String) -> (Int, Int)? {
        let pattern = #"(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard matches.count >= 2 else { return nil }

        func parts(_ match: NSTextCheckingResult) -> (hour: Int, minute: Int, meridiem: String?) {
            func group(_ index: Int) -> String? {
                Range(match.range(at: index), in: text).map { String(text[$0]) }
            }
            return (Int(group(1) ?? "") ?? 0, Int(group(2) ?? "") ?? 0, group(3)?.replacingOccurrences(of: ".", with: ""))
        }

        let open = parts(matches[0])
        let close = parts(matches[1])
        // Guess AM/PM when it's missing: shelters open in the morning and close in the afternoon.
        let openHour = to24(open.hour, open.meridiem ?? (open.hour >= 7 && open.hour < 12 ? "am" : "pm"))
        let opens = openHour * 60 + open.minute
        let closeHour: Int
        if let meridiem = close.meridiem {
            closeHour = to24(close.hour, meridiem)
        } else {
            // "9-5" means 5 PM: if the closing hour would be before opening, it's in the afternoon.
            closeHour = close.hour < 12 && close.hour * 60 + close.minute <= opens ? close.hour + 12 : close.hour
        }
        let closes = closeHour * 60 + close.minute
        return closes > opens ? (opens, closes) : nil
    }

    private static func to24(_ hour: Int, _ meridiem: String) -> Int {
        switch (hour, meridiem.lowercased().hasPrefix("p")) {
        case (12, false): 0
        case (12, true): 12
        case (_, true): hour + 12
        default: hour
        }
    }

    private static func timeText(_ minutes: Int) -> String {
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        guard let date = Calendar.current.date(from: components) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
