import Foundation

/// Miles or kilometres, chosen in Settings. Distances are always stored and
/// searched in miles; this only changes how they are written on screen.
enum DistanceUnit: String, CaseIterable, Identifiable {
    case miles
    case kilometers

    static let storageKey = "distanceUnit"
    private static let kilometersPerMile = 1.609344

    var id: String { rawValue }

    var title: String {
        switch self {
        case .miles: "Miles"
        case .kilometers: "Kilometers"
        }
    }

    var abbreviation: String {
        switch self {
        case .miles: "mi"
        case .kilometers: "km"
        }
    }

    /// The unit picked in Settings (miles until chosen; kilometres where the phone uses the metric system).
    static var current: DistanceUnit {
        if let saved = UserDefaults.standard.string(forKey: storageKey), let unit = DistanceUnit(rawValue: saved) {
            return unit
        }
        return Locale.current.measurementSystem == .us || Locale.current.measurementSystem == .uk ? .miles : .kilometers
    }

    /// A distance measured in miles, as a number in this unit.
    func value(fromMiles miles: Double) -> Double {
        self == .miles ? miles : miles * Self.kilometersPerMile
    }

    /// "25 mi" or "40 km" for a distance option stored in miles (used on chips and pickers).
    func label(miles: Int) -> String {
        let converted = value(fromMiles: Double(miles))
        return "\(Int(converted.rounded())) \(abbreviation)"
    }

    /// "12 mi" / "19 km" (or "1.4 mi" with `decimals: 1`).
    func text(miles: Double, decimals: Int = 0) -> String {
        String(format: "%.\(decimals)f \(abbreviation)", value(fromMiles: miles))
    }

    /// "12 mi away"
    func away(miles: Double) -> String {
        "\(text(miles: miles)) away"
    }
}
