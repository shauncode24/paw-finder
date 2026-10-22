import Foundation

/// Breed names for the listing form and for search suggestions. Built into
/// the app (no internet needed). Listers can still type any breed they like.
enum BreedCatalog {
    static let mixed = "Mixed Breed"

    static func breeds(for species: PetFilters.Species) -> [String] {
        switch species {
        case .dog: dogs
        case .cat: cats
        case .rabbit: rabbits
        case .bird: birds
        }
    }

    /// Breeds containing what was typed (starting-with matches first).
    static func suggestions(for species: PetFilters.Species, matching text: String, limit: Int = 6) -> [String] {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        let matches = breeds(for: species).filter { $0.localizedCaseInsensitiveContains(query) }
        let startsWith = matches.filter { $0.lowercased().hasPrefix(query.lowercased()) }
        let rest = matches.filter { !$0.lowercased().hasPrefix(query.lowercased()) }
        return Array((startsWith + rest).prefix(limit))
    }

    static let dogs: [String] = [
        "Akita", "Alaskan Malamute", "American Bulldog", "American Staffordshire Terrier", "Australian Cattle Dog",
        "Australian Shepherd", "Basset Hound", "Beagle", "Bernese Mountain Dog", "Bichon Frise", "Border Collie",
        "Boston Terrier", "Boxer", "Bulldog", "Cavalier King Charles Spaniel", "Chihuahua", "Chow Chow",
        "Cocker Spaniel", "Collie", "Dachshund", "Dalmatian", "Doberman Pinscher", "French Bulldog",
        "German Shepherd Dog", "German Shorthaired Pointer", "Golden Retriever", "Great Dane", "Greyhound",
        "Havanese", "Indian Pariah Dog", "Jack Russell Terrier", "Labrador Retriever", "Lhasa Apso", "Maltese",
        "Mastiff", "Miniature Schnauzer", "Newfoundland", "Pit Bull Terrier", "Pomeranian", "Poodle", "Pug",
        "Rhodesian Ridgeback", "Rottweiler", "Saint Bernard", "Samoyed", "Shiba Inu", "Shih Tzu",
        "Siberian Husky", "Staffordshire Bull Terrier", "Vizsla", "Weimaraner", "Yorkshire Terrier", mixed,
    ]

    static let cats: [String] = [
        "Abyssinian", "American Shorthair", "Bengal", "Birman", "Bombay", "British Shorthair", "Burmese",
        "Domestic Long Hair", "Domestic Medium Hair", "Domestic Short Hair", "Himalayan", "Maine Coon", "Manx",
        "Norwegian Forest Cat", "Persian", "Ragdoll", "Russian Blue", "Scottish Fold", "Siamese", "Siberian",
        "Sphynx", "Tabby", "Tortoiseshell", "Turkish Angora", mixed,
    ]

    static let rabbits: [String] = [
        "Dutch", "Flemish Giant", "Holland Lop", "Lionhead", "Mini Lop", "Mini Rex", "Netherland Dwarf", "Rex", mixed,
    ]

    static let birds: [String] = [
        "Budgerigar", "Canary", "Cockatiel", "Conure", "Finch", "Lovebird", "Parakeet", "Parrot", "Other",
    ]
}
