import Foundation

// The shape of Petfinder's JSON. Almost everything is optional because
// shelters leave fields blank. `toPet()` turns it into our own `Pet`.

struct PetfinderAnimalsResponse: Decodable {
    let animals: [PetfinderAnimal]
    let pagination: Pagination

    struct Pagination: Decodable {
        let currentPage: Int
        let totalPages: Int
    }
}

struct PetfinderAnimalResponse: Decodable {
    let animal: PetfinderAnimal
}

struct PetfinderBreedsResponse: Decodable {
    let breeds: [Breed]

    struct Breed: Decodable {
        let name: String
    }
}

struct PetfinderAnimal: Decodable {
    let id: Int
    let organizationId: String?
    let url: URL?
    let type: String?
    let breeds: Breeds?
    let age: String?
    let gender: String?
    let size: String?
    let attributes: Attributes?
    let environment: Environment?
    let tags: [String]?
    let name: String?
    let description: String?
    let photos: [Photo]?
    let publishedAt: String?   // e.g. "2026-09-04T14:49:09+0000"
    let distance: Double?      // only present when the request had a location
    let contact: Contact?

    struct Breeds: Decodable {
        let primary: String?
        let secondary: String?
        let mixed: Bool?
    }

    struct Attributes: Decodable {
        let houseTrained: Bool?
        let specialNeeds: Bool?
    }

    struct Environment: Decodable {
        let children: Bool?
        let dogs: Bool?
        let cats: Bool?
    }

    struct Photo: Decodable {
        let small: URL?
        let medium: URL?
        let large: URL?
        let full: URL?
    }

    struct Contact: Decodable {
        let address: Address?

        struct Address: Decodable {
            let city: String?
            let state: String?
        }
    }

    func toPet() -> Pet {
        Pet(
            id: String(id),
            name: name ?? "Unnamed",
            species: type ?? "",
            breed: breedText,
            age: age ?? "",
            gender: gender ?? "",
            size: size ?? "",
            description: description.map(Self.decodeEntities),
            photoURLs: (photos ?? []).compactMap { $0.large ?? $0.full ?? $0.medium },
            // "medium" is ~300px wide: small enough for grid cells, so we never
            // decode full-size photos just to show a thumbnail.
            thumbnailURL: photos?.first.flatMap { $0.medium ?? $0.small ?? $0.large },
            location: [contact?.address?.city, contact?.address?.state]
                .compactMap { $0 }
                .joined(separator: ", "),
            distance: distance,
            shelterID: organizationId ?? "",
            goodWithKids: environment?.children,
            goodWithDogs: environment?.dogs,
            goodWithCats: environment?.cats,
            houseTrained: attributes?.houseTrained ?? false,
            specialNeeds: attributes?.specialNeeds ?? false,
            tags: tags ?? [],
            publishedAt: publishedAt.flatMap(Self.dateFormatter.date(from:)),
            webURL: url
        )
    }

    private var breedText: String {
        let primary = breeds?.primary ?? "Unknown breed"
        if let secondary = breeds?.secondary {
            return "\(primary) / \(secondary)"
        }
        return breeds?.mixed == true ? "\(primary) Mix" : primary
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()

    /// Petfinder descriptions contain HTML entities like `&amp;` and `&#039;`.
    private static func decodeEntities(_ text: String) -> String {
        [("&amp;", "&"), ("&#039;", "'"), ("&quot;", "\""), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")]
            .reduce(text) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
    }
}
