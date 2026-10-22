import FirebaseFirestore
import Foundation

// MARK: - Status

/// Where a listing is in its life. Only "adopted" listings drop out of Discover.
enum ListingStatus: String, CaseIterable, Codable {
    case available, pending, adopted

    var title: String {
        switch self {
        case .available: "Available"
        case .pending: "Adoption pending"
        case .adopted: "Adopted"
        }
    }

    /// The value stored in `Pet.status`.
    var petStatus: String {
        switch self {
        case .available: "adoptable"
        case .pending: "pending"
        case .adopted: "adopted"
        }
    }

    init(petStatus: String?) {
        switch petStatus?.lowercased() {
        case "pending": self = .pending
        case "adopted": self = .adopted
        default: self = .available
        }
    }
}

/// Yes / No / Not sure, for questions like "good with kids?".
enum TriState: String, CaseIterable {
    case yes = "Yes"
    case no = "No"
    case unknown = "Not sure"

    init(_ value: Bool?) {
        switch value {
        case true?: self = .yes
        case false?: self = .no
        case nil: self = .unknown
        }
    }

    var value: Bool? {
        switch self {
        case .yes: true
        case .no: false
        case .unknown: nil
        }
    }
}

// MARK: - The listing form

/// Everything a lister can say about a pet. The listing form edits one of
/// these; `ListingMapper` turns it into a Firestore document and back.
struct ListingDraft: Equatable {
    var id: String?                 // nil while creating
    var createdAt: Date?
    var originalPhotoCount = 0      // how many photos the saved listing had (to clean up extras)

    // Basics
    var name = ""
    var species: PetFilters.Species = .dog
    var breed = ""
    var secondaryBreed = ""
    var isMixed = false

    // About them
    var age: PetFilters.Age = .young
    var ageDetail = ""              // "2 years 3 months" (optional)
    var gender: PetFilters.Gender = .female
    var size: PetFilters.Size = .medium
    var colors = ""
    var coat: PetFilters.Coat?
    var weight = ""
    var temperament: Set<String> = []

    // Home compatibility
    var goodWithKids: TriState = .unknown
    var goodWithDogs: TriState = .unknown
    var goodWithCats: TriState = .unknown
    var houseTrained = false

    // Health
    var vaccinated = false
    var spayedNeutered = false
    var microchipped = false
    var specialNeeds = false
    var specialNeedsNotes = ""
    var healthNotes = ""

    // Adoption
    var adoptionFee = ""            // typed as text; empty or 0 means free
    var description = ""
    var videoLink = ""
    var status: ListingStatus = .available

    // Fostering
    var fosterNeeded = false
    var fosterReason = ""
    var fosterDuration: FosterDuration = .weeks
    /// Set when a volunteer's offer was accepted; cleared to end the placement.
    var fosterByID = ""
    var fosterByName = ""

    // Where and how to reach the lister
    var city = ""
    var state = ""
    var postcode = ""
    var contactEmail = ""
    var contactPhone = ""

    /// JPEG bytes, already shrunk. The first one is the cover photo.
    var photos: [Data] = []

    static let maxPhotos = 5
    static let temperamentOptions = [
        "Friendly", "Playful", "Calm", "Energetic", "Affectionate", "Shy", "Independent",
        "Curious", "Gentle", "Protective", "Quiet", "Vocal", "Cuddly", "Smart",
    ]

    /// What's still missing before the listing can be published.
    var problems: [String] {
        var found: [String] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty { found.append("Give the pet a name.") }
        if breed.trimmingCharacters(in: .whitespaces).isEmpty { found.append("Choose a breed (or \"Mixed Breed\").") }
        if photos.isEmpty { found.append("Add at least one photo.") }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).count < 30 {
            found.append("Describe the pet in a few sentences (at least 30 characters).")
        }
        if city.trimmingCharacters(in: .whitespaces).isEmpty && postcode.trimmingCharacters(in: .whitespaces).isEmpty {
            found.append("Add a city or postcode so adopters can find you.")
        }
        if !adoptionFee.isEmpty, feeValue == nil { found.append("The adoption fee should be a number.") }
        if !videoLink.isEmpty, URL(string: videoLink)?.scheme?.hasPrefix("http") != true {
            found.append("The video link should start with http:// or https://.")
        }
        return found
    }

    /// The fee as a number (nil when blank or not a number).
    var feeValue: Double? {
        let text = adoptionFee.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return 0 }
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }
}

// MARK: - Firestore ⇄ app

/// Converts between Firestore documents and the app's types. Written field by
/// field (no automatic coding), so it's clear exactly what is stored.
///
/// `listings/{id}` fields: ownerID, ownerName, name, species, breed, secondaryBreed,
/// mixed, age, ageDetail, gender, size, colors, coat, weight, temperament[],
/// goodWithKids/Dogs/Cats (omitted = not sure), houseTrained, vaccinated, spayedNeutered,
/// microchipped, specialNeeds, specialNeedsNotes, healthNotes, adoptionFee, description,
/// city, state, postcode, latitude, longitude, contactEmail, contactPhone, videoLink,
/// status, isActive, photoCount, thumbnail (base64 JPEG), createdAt, updatedAt.
enum ListingMapper {
    // MARK: Document → Pet

    static func pet(id: String, data d: [String: Any]) -> Pet? {
        guard let name = d["name"] as? String, let ownerID = d["ownerID"] as? String else { return nil }

        let primary = (d["breed"] as? String) ?? "Unknown breed"
        let secondary = (d["secondaryBreed"] as? String) ?? ""
        let mixed = (d["mixed"] as? Bool) ?? false
        let breedText: String
        if !secondary.isEmpty {
            breedText = "\(primary) / \(secondary)"
        } else {
            breedText = mixed && primary != "Mixed Breed" ? "\(primary) Mix" : primary
        }

        let city = (d["city"] as? String) ?? ""
        let state = (d["state"] as? String) ?? ""
        var location = [city, state].filter { !$0.isEmpty }.joined(separator: ", ")
        if location.isEmpty { location = (d["postcode"] as? String) ?? "" }

        let photoCount = (d["photoCount"] as? Int) ?? 0
        let photoURLs: [URL] = (0..<photoCount).compactMap { PhotoURL.photo($0, of: id) }
        let createdAt = (d["createdAt"] as? Timestamp)?.dateValue()

        var pet = Pet(
            id: id,
            name: name,
            species: (d["species"] as? String) ?? "Dog",
            breed: breedText,
            age: (d["age"] as? String) ?? "",
            gender: (d["gender"] as? String) ?? "",
            size: (d["size"] as? String) ?? "",
            description: d["description"] as? String,
            photoURLs: photoURLs,
            thumbnailURL: photoCount > 0 ? PhotoURL.thumbnail(of: id) : nil,
            location: location,
            distance: nil,
            shelterID: ownerID,
            goodWithKids: d["goodWithKids"] as? Bool,
            goodWithDogs: d["goodWithDogs"] as? Bool,
            goodWithCats: d["goodWithCats"] as? Bool,
            houseTrained: (d["houseTrained"] as? Bool) ?? false,
            specialNeeds: (d["specialNeeds"] as? Bool) ?? false,
            tags: (d["temperament"] as? [String]) ?? [],
            publishedAt: createdAt,
            webURL: nil
        )
        pet.primaryBreed = primary
        pet.contactEmail = nonEmpty(d["contactEmail"] as? String)
        pet.contactPhone = nonEmpty(d["contactPhone"] as? String)
        pet.status = ListingStatus(petStatus: d["status"] as? String).petStatus
        pet.coat = nonEmpty(d["coat"] as? String)
        pet.ageDetail = nonEmpty(d["ageDetail"] as? String)
        pet.colors = nonEmpty(d["colors"] as? String)
        pet.weight = nonEmpty(d["weight"] as? String)
        pet.vaccinated = d["vaccinated"] as? Bool
        pet.spayedNeutered = d["spayedNeutered"] as? Bool
        pet.microchipped = d["microchipped"] as? Bool
        pet.specialNeedsNotes = nonEmpty(d["specialNeedsNotes"] as? String)
        pet.healthNotes = nonEmpty(d["healthNotes"] as? String)
        pet.adoptionFee = number(d["adoptionFee"])
        pet.listedBy = nonEmpty(d["ownerName"] as? String)
        pet.videoLink = (d["videoLink"] as? String).flatMap(URL.init(string:))
        pet.latitude = d["latitude"] as? Double
        pet.longitude = d["longitude"] as? Double
        pet.fosterNeeded = d["fosterNeeded"] as? Bool
        pet.fosterReason = nonEmpty(d["fosterReason"] as? String)
        pet.fosterDuration = nonEmpty(d["fosterDuration"] as? String)
        pet.fosterByID = nonEmpty(d["fosterByID"] as? String)
        pet.fosterByName = nonEmpty(d["fosterByName"] as? String)
        return pet
    }

    // MARK: Document → editable draft

    static func draft(id: String, data d: [String: Any]) -> ListingDraft {
        var draft = ListingDraft()
        draft.id = id
        draft.createdAt = (d["createdAt"] as? Timestamp)?.dateValue()
        draft.originalPhotoCount = (d["photoCount"] as? Int) ?? 0
        draft.name = (d["name"] as? String) ?? ""
        draft.species = PetFilters.Species(rawValue: (d["species"] as? String) ?? "") ?? .dog
        draft.breed = (d["breed"] as? String) ?? ""
        draft.secondaryBreed = (d["secondaryBreed"] as? String) ?? ""
        draft.isMixed = (d["mixed"] as? Bool) ?? false
        draft.age = PetFilters.Age(rawValue: (d["age"] as? String) ?? "") ?? .young
        draft.ageDetail = (d["ageDetail"] as? String) ?? ""
        draft.gender = PetFilters.Gender(rawValue: (d["gender"] as? String) ?? "") ?? .female
        draft.size = PetFilters.Size(rawValue: (d["size"] as? String) ?? "") ?? .medium
        draft.colors = (d["colors"] as? String) ?? ""
        draft.coat = (d["coat"] as? String).flatMap(PetFilters.Coat.init(rawValue:))
        draft.weight = (d["weight"] as? String) ?? ""
        draft.temperament = Set((d["temperament"] as? [String]) ?? [])
        draft.goodWithKids = TriState(d["goodWithKids"] as? Bool)
        draft.goodWithDogs = TriState(d["goodWithDogs"] as? Bool)
        draft.goodWithCats = TriState(d["goodWithCats"] as? Bool)
        draft.houseTrained = (d["houseTrained"] as? Bool) ?? false
        draft.vaccinated = (d["vaccinated"] as? Bool) ?? false
        draft.spayedNeutered = (d["spayedNeutered"] as? Bool) ?? false
        draft.microchipped = (d["microchipped"] as? Bool) ?? false
        draft.specialNeeds = (d["specialNeeds"] as? Bool) ?? false
        draft.specialNeedsNotes = (d["specialNeedsNotes"] as? String) ?? ""
        draft.healthNotes = (d["healthNotes"] as? String) ?? ""
        let fee: Double = number(d["adoptionFee"]) ?? 0
        let formatString: String = fee.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f"
        draft.adoptionFee = fee > 0 ? String(format: formatString, fee) : ""
        draft.description = (d["description"] as? String) ?? ""
        draft.videoLink = (d["videoLink"] as? String) ?? ""
        draft.status = ListingStatus(petStatus: d["status"] as? String)
        draft.city = (d["city"] as? String) ?? ""
        draft.state = (d["state"] as? String) ?? ""
        draft.postcode = (d["postcode"] as? String) ?? ""
        draft.contactEmail = (d["contactEmail"] as? String) ?? ""
        draft.contactPhone = (d["contactPhone"] as? String) ?? ""
        draft.fosterNeeded = (d["fosterNeeded"] as? Bool) ?? false
        draft.fosterReason = (d["fosterReason"] as? String) ?? ""
        draft.fosterDuration = FosterDuration(rawValue: (d["fosterDuration"] as? String) ?? "") ?? .weeks
        draft.fosterByID = (d["fosterByID"] as? String) ?? ""
        draft.fosterByName = (d["fosterByName"] as? String) ?? ""
        return draft
    }

    // MARK: Draft → document

    /// - Parameters:
    ///   - thumbnail: the card photo, base64 text.
    ///   - coordinate: where the listing is (looked up from the city/postcode).
    static func data(from draft: ListingDraft, ownerID: String, ownerName: String, photoCount: Int,
                     thumbnail: String?, latitude: Double?, longitude: Double?) -> [String: Any] {
        var d: [String: Any] = [
            "ownerID": ownerID,
            "ownerName": ownerName,
            "name": trimmed(draft.name),
            "species": draft.species.rawValue,
            "breed": trimmed(draft.breed),
            "mixed": draft.isMixed || !trimmed(draft.secondaryBreed).isEmpty,
            "age": draft.age.rawValue,
            "gender": draft.gender.rawValue,
            "size": draft.size.rawValue,
            "temperament": draft.temperament.sorted(),
            "houseTrained": draft.houseTrained,
            "vaccinated": draft.vaccinated,
            "spayedNeutered": draft.spayedNeutered,
            "microchipped": draft.microchipped,
            "specialNeeds": draft.specialNeeds,
            "adoptionFee": draft.feeValue ?? 0,
            "description": draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
            "city": trimmed(draft.city),
            "state": trimmed(draft.state),
            "postcode": trimmed(draft.postcode),
            "status": draft.status.rawValue,
            "isActive": draft.status != .adopted,
            "photoCount": photoCount,
            "createdAt": Timestamp(date: draft.createdAt ?? .now),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        // Optional text: only stored when filled in.
        let optionalText: [String: String] = [
            "secondaryBreed": draft.secondaryBreed,
            "ageDetail": draft.ageDetail,
            "colors": draft.colors,
            "weight": draft.weight,
            "specialNeedsNotes": draft.specialNeeds ? draft.specialNeedsNotes : "",
            "healthNotes": draft.healthNotes,
            "contactEmail": draft.contactEmail,
            "contactPhone": draft.contactPhone,
            "videoLink": draft.videoLink,
        ]
        for (key, value) in optionalText where !trimmed(value).isEmpty {
            d[key] = trimmed(value)
        }
        if let coat = draft.coat { d["coat"] = coat.rawValue }
        // Fostering: "needs a foster" and "already with a foster" are mutually exclusive.
        let fostered = !trimmed(draft.fosterByName).isEmpty
        d["fosterNeeded"] = draft.fosterNeeded && !fostered
        if draft.fosterNeeded && !fostered {
            if !trimmed(draft.fosterReason).isEmpty { d["fosterReason"] = trimmed(draft.fosterReason) }
            d["fosterDuration"] = draft.fosterDuration.rawValue
        }
        if fostered {
            d["fosterByID"] = trimmed(draft.fosterByID)
            d["fosterByName"] = trimmed(draft.fosterByName)
        }
        // Yes/No answers; "Not sure" is simply left out.
        if let value = draft.goodWithKids.value { d["goodWithKids"] = value }
        if let value = draft.goodWithDogs.value { d["goodWithDogs"] = value }
        if let value = draft.goodWithCats.value { d["goodWithCats"] = value }
        if let thumbnail { d["thumbnail"] = thumbnail }
        if let latitude, let longitude {
            d["latitude"] = latitude
            d["longitude"] = longitude
        }
        return d
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Firestore hands back whole numbers as Int and others as Double.
    private static func number(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        return nil
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return text
    }
}

// MARK: - Filtering (used on the phone, since listings arrive as a live feed)

extension PetFilters {
    /// Does this pet match everything except location (handled separately, since it needs geocoding)?
    func matches(_ pet: Pet) -> Bool {
        let query = name.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty,
           !(pet.name.localizedCaseInsensitiveContains(query) || pet.breed.localizedCaseInsensitiveContains(query)) {
            return false
        }
        if let species, pet.species != species.rawValue { return false }
        if let breed, !pet.breed.localizedCaseInsensitiveContains(breed) { return false }
        if let shelterID, pet.shelterID != shelterID { return false }
        if !ages.isEmpty, !ages.map(\.rawValue).contains(pet.age) { return false }
        if !sizes.isEmpty, !sizes.map(\.rawValue).contains(pet.size) { return false }
        if let gender, pet.gender != gender.rawValue { return false }
        if goodWithKids, pet.goodWithKids != true { return false }
        if goodWithDogs, pet.goodWithDogs != true { return false }
        if goodWithCats, pet.goodWithCats != true { return false }
        if houseTrained, !pet.houseTrained { return false }
        if specialNeeds, !pet.specialNeeds { return false }
        if needsFoster == true, !pet.needsFoster { return false }
        if !coats.isEmpty, !coats.map(\.rawValue).contains(pet.coat ?? "") { return false }
        if let dateFilter = listed.dateFilter, let published = pet.publishedAt {
            if dateFilter.key == "after", published < dateFilter.date { return false }
            if dateFilter.key == "before", published > dateFilter.date { return false }
        }
        return true
    }
}
