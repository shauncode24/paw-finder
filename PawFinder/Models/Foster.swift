import FirebaseFirestore
import Foundation

/// How long a foster stay lasts (or is needed for).
enum FosterDuration: String, CaseIterable, Identifiable {
    case days = "A few days"
    case weeks = "A few weeks"
    case openEnded = "Until adopted"

    var id: String { rawValue }
}

/// A foster volunteer's public-to-listers profile: a person who can look after a
/// pet at home for a while. Stored in `fosters/{uid}`. Only the volunteer and
/// signed-in listers can read it, and it holds a city, never a street address.
struct FosterProfile: Equatable {
    var uid: String
    var displayName = ""
    /// Hidden from the directory when false (the volunteer can pause any time).
    var isAvailable = true
    var species: Set<PetFilters.Species> = [.dog, .cat]
    var sizes: Set<PetFilters.Size> = [.small, .medium]
    var capacity = 1
    var duration: FosterDuration = .weeks
    var homeType: AdopterProfile.HomeType?
    var hasOtherPets = false
    var otherPetsNote = ""
    var experience: AdopterProfile.Experience?
    var bio = ""
    var city = ""
    var state = ""
    var postcode = ""
    var latitude: Double?
    var longitude: Double?
    var updatedAt: Date?

    init(uid: String) {
        self.uid = uid
    }

    init(uid: String, data d: [String: Any]) {
        self.uid = uid
        displayName = (d["displayName"] as? String) ?? ""
        isAvailable = (d["isAvailable"] as? Bool) ?? true
        species = Set(((d["species"] as? [String]) ?? []).compactMap(PetFilters.Species.init(rawValue:)))
        sizes = Set(((d["sizes"] as? [String]) ?? []).compactMap(PetFilters.Size.init(rawValue:)))
        capacity = (d["capacity"] as? Int) ?? 1
        duration = FosterDuration(rawValue: (d["duration"] as? String) ?? "") ?? .weeks
        homeType = (d["homeType"] as? String).flatMap(AdopterProfile.HomeType.init(rawValue:))
        hasOtherPets = (d["hasOtherPets"] as? Bool) ?? false
        otherPetsNote = (d["otherPetsNote"] as? String) ?? ""
        experience = (d["experience"] as? String).flatMap(AdopterProfile.Experience.init(rawValue:))
        bio = (d["bio"] as? String) ?? ""
        city = (d["city"] as? String) ?? ""
        state = (d["state"] as? String) ?? ""
        postcode = (d["postcode"] as? String) ?? ""
        latitude = d["latitude"] as? Double
        longitude = d["longitude"] as? Double
        updatedAt = (d["updatedAt"] as? Timestamp)?.dateValue()
    }

    /// The first name and last initial shown to listers.
    var publicName: String {
        let parts = displayName.split(separator: " ")
        guard let first = parts.first else { return "A foster volunteer" }
        guard parts.count > 1, let initial = parts.last?.first else { return String(first) }
        return "\(first) \(initial)."
    }

    var cityState: String {
        [city, state].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: ", ")
    }

    var coordinateText: String? {
        guard let latitude, let longitude else { return nil }
        return String(format: "%.4f,%.4f", latitude, longitude)
    }

    /// "Dogs, cats · small, medium · up to 2 at a time"
    var summary: String {
        let kinds: String = PetFilters.Species.allCases.filter { species.contains($0) }.map(\.rawValue).joined(separator: ", ")
        let bodies: String = PetFilters.Size.allCases.filter { sizes.contains($0) }.map { $0.rawValue.lowercased() }.joined(separator: ", ")
        return "\(kinds) · \(bodies) · up to \(capacity) at a time"
    }

    var problems: [String] {
        var found: [String] = []
        if displayName.trimmingCharacters(in: .whitespaces).isEmpty { found.append("Add your name.") }
        if species.isEmpty { found.append("Choose at least one kind of animal.") }
        if sizes.isEmpty { found.append("Choose at least one size.") }
        if city.trimmingCharacters(in: .whitespaces).isEmpty && postcode.trimmingCharacters(in: .whitespaces).isEmpty {
            found.append("Add your city or postcode so listers can find you.")
        }
        return found
    }

    func data() -> [String: Any] {
        var d: [String: Any] = [
            "displayName": displayName.trimmingCharacters(in: .whitespaces),
            "isAvailable": isAvailable,
            "species": species.map(\.rawValue).sorted(),
            "sizes": sizes.map(\.rawValue).sorted(),
            "capacity": capacity,
            "duration": duration.rawValue,
            "hasOtherPets": hasOtherPets,
            "otherPetsNote": hasOtherPets ? otherPetsNote.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            "bio": bio.trimmingCharacters(in: .whitespacesAndNewlines),
            "city": city.trimmingCharacters(in: .whitespaces),
            "state": state.trimmingCharacters(in: .whitespaces),
            "postcode": postcode.trimmingCharacters(in: .whitespaces),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if let homeType { d["homeType"] = homeType.rawValue }
        if let experience { d["experience"] = experience.rawValue }
        return d
    }
}

// MARK: - Offers

enum FosterOfferStatus: String {
    case pending, accepted, declined, withdrawn

    var label: String {
        switch self {
        case .pending: "Waiting for a reply"
        case .accepted: "Accepted"
        case .declined: "Declined"
        case .withdrawn: "Withdrawn"
        }
    }

    var icon: String {
        switch self {
        case .pending: "clock"
        case .accepted: "checkmark.circle.fill"
        case .declined: "xmark.circle"
        case .withdrawn: "arrow.uturn.backward.circle"
        }
    }
}

/// A foster volunteer's offer to look after a pet that needs a foster.
/// Stored in `fosterOffers/{listingID}_{fosterID}` (one offer per volunteer per pet).
struct FosterOffer: Identifiable, Hashable {
    let id: String
    let listingID: String
    var listingName: String
    var listingSpecies: String
    let listerID: String
    var listerName: String
    let fosterID: String
    var fosterName: String
    var message: String
    var duration: FosterDuration
    var status: FosterOfferStatus
    var createdAt: Date
    var updatedAt: Date

    static func makeID(listingID: String, fosterID: String) -> String { "\(listingID)_\(fosterID)" }

    init?(id: String, data d: [String: Any]) {
        guard let listingID = d["listingID"] as? String,
              let listerID = d["listerID"] as? String,
              let fosterID = d["fosterID"] as? String else { return nil }
        self.id = id
        self.listingID = listingID
        self.listerID = listerID
        self.fosterID = fosterID
        listingName = (d["listingName"] as? String) ?? "a pet"
        listingSpecies = (d["listingSpecies"] as? String) ?? "Dog"
        listerName = (d["listerName"] as? String) ?? "the lister"
        fosterName = (d["fosterName"] as? String) ?? "A volunteer"
        message = (d["message"] as? String) ?? ""
        duration = FosterDuration(rawValue: (d["duration"] as? String) ?? "") ?? .weeks
        status = FosterOfferStatus(rawValue: (d["status"] as? String) ?? "") ?? .pending
        createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? .now
        updatedAt = (d["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
    }
}
