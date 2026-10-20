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
        guard var pet = Self.samplePets.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        // Pretend Charlie (mock-5) just got adopted, so favorites can show a status change.
        if id == "mock-5" { pet.status = "adopted" }
        return pet
    }

    func fetchShelter(id: String) async throws -> Shelter {
        try await Task.sleep(for: delay)
        guard let shelter = Self.sampleShelters.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        return shelter
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
        if filters.specialNeeds, !pet.specialNeeds { return false }
        if !filters.coats.isEmpty, !filters.coats.map(\.rawValue).contains(pet.coat ?? "") { return false }
        if let dateFilter = filters.listed.dateFilter, let published = pet.publishedAt {
            if dateFilter.key == "after", published < dateFilter.date { return false }
            if dateFilter.key == "before", published > dateFilter.date { return false }
        }
        return true
    }

    // MARK: - Sample data

    static let dogBreeds = ["Beagle", "Labrador Retriever", "German Shepherd Dog", "Golden Retriever", "Pit Bull Terrier"]
    static let catBreeds = ["Domestic Short Hair", "Siamese", "Maine Coon", "Tabby", "Persian"]

    static let sampleShelters: [Shelter] = [
        Shelter(id: "shelter-1", name: "Austin Animal Center", email: "adopt@example.com", phone: "(512) 555-0101",
                address: "7201 Levander Loop, Austin, TX 78702", website: URL(string: "https://www.austintexas.gov/austin-animal-center"),
                petfinderURL: nil),
        Shelter(id: "shelter-2", name: "Denver Animal Shelter", email: "adopt@example.com", phone: "(720) 555-0102",
                address: "1241 W Bayaud Ave, Denver, CO 80223", website: nil, petfinderURL: nil),
        Shelter(id: "shelter-3", name: "Portland Pet Rescue", email: nil, phone: "(503) 555-0103",
                address: "1067 NE Columbia Blvd, Portland, OR 97211", website: nil, petfinderURL: nil),
        Shelter(id: "shelter-4", name: "Chicago Paws Rescue", email: "hello@example.com", phone: nil,
                address: "2741 S Western Ave, Chicago, IL 60608", website: nil, petfinderURL: nil),
    ]

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
                description: "\(name) is a friendly \(isDog ? "pup" : "cat") looking for a loving home. "
                    + "\(name) loves walks, treats, and naps in the sun, and gets along well with most people. "
                    + "Ask the shelter about a meet-and-greet to see if \(name) is the right fit for your family.",
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
                // Spread from today back to ~2 years ago, so every "time listed" filter has matches.
                publishedAt: Calendar.current.date(byAdding: .day, value: -index * index, to: .now),
                webURL: nil,
                primaryBreed: breeds[index % breeds.count],
                contactEmail: "adopt@example.com",
                contactPhone: "(555) 555-01\(String(format: "%02d", index))",
                status: "adoptable",
                coat: ["Short", "Medium", "Long"][index % 3]
            )
        }
    }()
}
