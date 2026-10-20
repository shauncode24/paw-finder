import Foundation

/// Fake pets for previews, and for running the app without API keys.
struct MockPetRepository: PetRepository {
    var pageSize = 10
    /// Fake network delay so loading states are visible.
    var delay: Duration = .milliseconds(600)

    func fetchPets(page: Int, type: String?) async throws -> PetPage {
        try await Task.sleep(for: delay)

        let matching = Self.samplePets.filter { pet in
            guard let type else { return true }
            return pet.species.lowercased() == type.lowercased()
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

    // MARK: - Sample data

    static let samplePets: [Pet] = {
        let names = ["Biscuit", "Luna", "Milo", "Bella", "Charlie", "Nala", "Oliver", "Daisy", "Max", "Coco",
                     "Leo", "Ruby", "Simba", "Rosie", "Buddy", "Cleo", "Teddy", "Willow", "Rocky", "Pepper",
                     "Ziggy", "Hazel", "Bear", "Olive", "Tucker"]
        let dogBreeds = ["Beagle", "Labrador Retriever", "German Shepherd", "Golden Retriever", "Pit Bull Terrier"]
        let catBreeds = ["Domestic Short Hair", "Siamese", "Maine Coon", "Tabby", "Persian"]
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
                location: cities[index % cities.count],
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
