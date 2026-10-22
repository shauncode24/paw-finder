import FirebaseFirestore
import Foundation

/// A lister's public profile: the person or rescue group behind a listing.
/// Stored in `users/{uid}`. Anyone can read these (adopters see who they're
/// talking to); only the owner can change theirs.
///
/// A user becomes a "lister" the first time they save this profile. It's the
/// same account as their adopter side: nothing separate to sign in to.
struct ListerProfile: Equatable {
    var uid: String
    var displayName = ""
    var isOrganization = false        // a rescue or shelter, rather than an individual
    var organization = ""             // the group's name, when isOrganization
    var bio = ""
    var city = ""
    var state = ""
    var postcode = ""
    var latitude: Double?
    var longitude: Double?
    var contactEmail = ""
    var contactPhone = ""
    var website = ""
    var adoptionPolicy = ""           // e.g. "Home visit required, 18+"
    var hasAvatar = false
    var isLister = false
    var createdAt: Date?

    /// The name shown on listings and in chats.
    var publicName: String {
        let group = organization.trimmingCharacters(in: .whitespaces)
        if isOrganization, !group.isEmpty { return group }
        return displayName
    }

    init(uid: String) {
        self.uid = uid
    }

    init(uid: String, data d: [String: Any]) {
        self.uid = uid
        displayName = (d["displayName"] as? String) ?? ""
        isOrganization = (d["isOrganization"] as? Bool) ?? false
        organization = (d["organization"] as? String) ?? ""
        bio = (d["bio"] as? String) ?? ""
        city = (d["city"] as? String) ?? ""
        state = (d["state"] as? String) ?? ""
        postcode = (d["postcode"] as? String) ?? ""
        latitude = d["latitude"] as? Double
        longitude = d["longitude"] as? Double
        contactEmail = (d["contactEmail"] as? String) ?? ""
        contactPhone = (d["contactPhone"] as? String) ?? ""
        website = (d["website"] as? String) ?? ""
        adoptionPolicy = (d["adoptionPolicy"] as? String) ?? ""
        hasAvatar = (d["avatar"] as? String)?.isEmpty == false
        isLister = (d["isLister"] as? Bool) ?? false
        createdAt = (d["createdAt"] as? Timestamp)?.dateValue()
    }

    /// The fields to save (the avatar is handled separately, since it's large).
    func data() -> [String: Any] {
        [
            "displayName": displayName.trimmingCharacters(in: .whitespaces),
            "isOrganization": isOrganization,
            "organization": organization.trimmingCharacters(in: .whitespaces),
            "bio": bio.trimmingCharacters(in: .whitespacesAndNewlines),
            "city": city.trimmingCharacters(in: .whitespaces),
            "state": state.trimmingCharacters(in: .whitespaces),
            "postcode": postcode.trimmingCharacters(in: .whitespaces),
            "contactEmail": contactEmail.trimmingCharacters(in: .whitespaces),
            "contactPhone": contactPhone.trimmingCharacters(in: .whitespaces),
            "website": website.trimmingCharacters(in: .whitespaces),
            "adoptionPolicy": adoptionPolicy.trimmingCharacters(in: .whitespacesAndNewlines),
            "isLister": isLister,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
    }

    /// The version other people see (used on pet pages, the map, and lister pages).
    func shelter() -> Shelter {
        var shelter = Shelter(
            id: uid,
            name: publicName.isEmpty ? "A PawFinder lister" : publicName,
            email: Self.nonEmpty(contactEmail),
            phone: Self.nonEmpty(contactPhone),
            address: "",
            website: Self.webURL(website)
        )
        shelter.city = Self.nonEmpty(city)
        shelter.state = Self.nonEmpty(state)
        shelter.postcode = Self.nonEmpty(postcode)
        shelter.missionStatement = Self.nonEmpty(bio)
        shelter.photoURLs = hasAvatar ? [PhotoURL.avatar(of: uid)].compactMap { $0 } : []
        shelter.adoptionPolicy = Self.nonEmpty(adoptionPolicy)
        shelter.latitude = latitude
        shelter.longitude = longitude
        shelter.isOrganization = isOrganization
        return shelter
    }

    private static func nonEmpty(_ text: String) -> String? {
        text.trimmingCharacters(in: .whitespaces).isEmpty ? nil : text
    }

    /// People often type "www.example.org" without https://.
    private static func webURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.lowercased().hasPrefix("http") ? trimmed : "https://\(trimmed)"
        return URL(string: withScheme)
    }
}
