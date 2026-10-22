import Foundation

/// A tiny in-memory repository for SwiftUI previews only. The running app
/// never uses it: real data comes from `FirestoreListingsRepository`.
struct MockPetRepository: PetRepository {
    func fetchPets(page: Int, filters: PetFilters) async throws -> PetPage {
        let matching = Self.samplePets.filter { filters.matches($0) }
        return PetPage(pets: matching, currentPage: 1, totalPages: 1)
    }

    func fetchPet(id: String) async throws -> Pet {
        guard let pet = Self.samplePets.first(where: { $0.id == id }) else { throw APIError.notFound }
        return pet
    }

    func fetchBreeds(for species: PetFilters.Species) async throws -> [String] {
        BreedCatalog.breeds(for: species)
    }

    func fetchShelter(id: String) async throws -> Shelter {
        guard let shelter = Self.sampleShelters.first(where: { $0.id == id }) else { throw APIError.notFound }
        return shelter
    }

    func fetchShelters(near location: String, distance: Int, page: Int) async throws -> ShelterPage {
        ShelterPage(shelters: Self.sampleShelters, currentPage: 1, totalPages: 1)
    }

    // MARK: - Preview data

    static let sampleShelters: [Shelter] = {
        func lister(_ number: Int, _ name: String, _ city: String, _ state: String) -> Shelter {
            var shelter = Shelter(id: "shelter-\(number)", name: name, email: "hello@example.com",
                                  phone: "(555) 555-01\(number)0", address: "", website: nil)
            shelter.city = city
            shelter.state = state
            shelter.missionStatement = "\(name) rehomes pets in the \(city) area."
            shelter.isOrganization = true
            return shelter
        }
        return [
            lister(1, "Sunny Paws Rescue", "Austin", "TX"),
            lister(2, "Mile High Animal Friends", "Denver", "CO"),
            lister(3, "Rose City Strays", "Portland", "OR"),
        ]
    }()

    static let samplePets: [Pet] = {
        let rows: [(name: String, species: String, breed: String, age: String, gender: String, size: String)] = [
            ("Biscuit", "Dog", "Beagle", "Young", "Male", "Medium"),
            ("Luna", "Cat", "Domestic Short Hair", "Adult", "Female", "Small"),
            ("Milo", "Dog", "Labrador Retriever", "Baby", "Male", "Large"),
            ("Bella", "Dog", "Golden Retriever", "Senior", "Female", "Large"),
            ("Nala", "Cat", "Siamese", "Young", "Female", "Small"),
            ("Max", "Dog", "Pit Bull Terrier", "Adult", "Male", "Medium"),
        ]
        return rows.enumerated().map { index, row in
            let shelter = sampleShelters[index % sampleShelters.count]
            var pet = Pet(
                id: "preview-\(index + 1)", name: row.name, species: row.species, breed: row.breed, age: row.age,
                gender: row.gender, size: row.size,
                description: "\(row.name) is a friendly \(row.species.lowercased()) looking for a loving home.",
                photoURLs: [], thumbnailURL: nil, location: shelter.cityState, distance: nil,
                shelterID: shelter.id, goodWithKids: index.isMultiple(of: 2), goodWithDogs: true, goodWithCats: nil,
                houseTrained: true, specialNeeds: false, tags: ["Friendly", "Playful"],
                publishedAt: Calendar.current.date(byAdding: .day, value: -index * 4, to: .now), webURL: nil
            )
            pet.status = "adoptable"
            pet.listedBy = shelter.name
            pet.vaccinated = true
            pet.spayedNeutered = true
            return pet
        }
    }()
}
