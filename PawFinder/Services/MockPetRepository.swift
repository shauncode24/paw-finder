import Foundation

/// Fake pets for previews, and for running the app without API keys.
/// Applies filters roughly the way Petfinder does, so the UI can be tested.
struct MockPetRepository: PetRepository {
    var pageSize = 10
    /// Fake network delay so loading states are visible.
    var delay: Duration = .milliseconds(600)

    func fetchPets(page: Int, filters: PetFilters) async throws -> PetPage {
        try await Task.sleep(for: delay)

        var matching = Self.samplePets.filter { matches($0, filters) }
        switch filters.sort {
        case .newest, .nearest:
            matching.sort { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        case .longestWaiting:
            matching.sort { ($0.publishedAt ?? .distantPast) < ($1.publishedAt ?? .distantPast) }
        case .random:
            matching.shuffle()
        }

        let totalPages = max(1, Int((Double(matching.count) / Double(pageSize)).rounded(.up)))
        let pagePets = Array(matching.dropFirst((page - 1) * pageSize).prefix(pageSize))
        return PetPage(pets: pagePets, currentPage: page, totalPages: totalPages)
    }

    func fetchPet(id: String) async throws -> Pet {
        try await Task.sleep(for: delay)
        guard let pet = Self.samplePets.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        return pet
    }

    func fetchBreeds(for species: PetFilters.Species) async throws -> [String] {
        switch species {
        case .dog: Self.dogBreeds
        case .cat: Self.catBreeds
        case .rabbit, .bird: []
        }
    }

    private func matches(_ pet: Pet, _ filters: PetFilters) -> Bool {
        let name = filters.name.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty, !pet.name.localizedCaseInsensitiveContains(name) { return false }
        if let species = filters.species, pet.species != species.rawValue { return false }
        if let breed = filters.breed, !pet.breed.localizedCaseInsensitiveContains(breed) { return false }
        if !filters.ages.isEmpty, !filters.ages.map(\.rawValue).contains(pet.age) { return false }
        if !filters.sizes.isEmpty, !filters.sizes.map(\.rawValue).contains(pet.size) { return false }
        if let gender = filters.gender, pet.gender != gender.rawValue { return false }
        if filters.goodWithKids, pet.goodWithKids != true { return false }
        if filters.goodWithDogs, pet.goodWithDogs != true { return false }
        if filters.goodWithCats, pet.goodWithCats != true { return false }
        if filters.houseTrained, !pet.houseTrained { return false }
        return true
    }

    // MARK: - Sample data

    static let dogBreeds = ["Beagle", "Labrador Retriever", "German Shepherd Dog", "Golden Retriever", "Pit Bull Terrier"]
    static let catBreeds = ["Domestic Short Hair", "Siamese", "Maine Coon", "Tabby", "Persian"]

    static let samplePets: [Pet] = {
        let names = ["Biscuit", "Luna", "Milo", "Bella", "Charlie", "Nala", "Oliver", "Daisy", "Max", "Coco",
                     "Leo", "Ruby", "Simba", "Rosie", "Buddy", "Cleo", "Teddy", "Willow", "Rocky", "Pepper",
                     "Ziggy", "Hazel", "Bear", "Olive", "Tucker"]
        let ages = ["Baby", "Young", "Adult", "Senior"]
        let sizes = ["Small", "Medium", "Large"]
        let cities = ["Austin, TX", "Denver, CO", "Portland, OR", "Chicago, IL", "Raleigh, NC"]

        return names.enumerated().map { index, name in
            let isDog = index % 3 != 2
            let breeds = isDog ? dogBreeds : catBreeds
            return Pet(
                id: "mock-\(index + 1)",
                name: name,
                species: isDog ? "Dog" : "Cat",
                breed: breeds[index % breeds.count],
                age: ages[index % ages.count],
                gender: index.isMultiple(of: 2) ? "Female" : "Male",
                size: sizes[index % sizes.count],
                description: "\(name) is a friendly \(isDog ? "pup" : "cat") looking for a loving home.",
                photoURLs: [],
                thumbnailURL: nil,
                location: cities[index % cities.count],
                distance: nil,
                shelterID: "shelter-\(index % 4 + 1)",
                goodWithKids: index % 4 == 3 ? nil : index % 4 != 1,
                goodWithDogs: isDog ? true : nil,
                goodWithCats: isDog ? index.isMultiple(of: 2) : true,
                houseTrained: index % 3 != 0,
                specialNeeds: index == 7,
                tags: ["Friendly", "Playful", "Gentle", "Curious"].shuffled().prefix(2).map { $0 },
                publishedAt: Calendar.current.date(byAdding: .day, value: -index * 3, to: .now),
                webURL: nil
            )
        }
    }()
}
