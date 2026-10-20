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

    func fetchShelters(near location: String, distance: Int, page: Int) async throws -> ShelterPage {
        try await Task.sleep(for: delay)
        return ShelterPage(shelters: page == 1 ? Self.sampleShelters : [], currentPage: page, totalPages: 1)
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
        if let shelterID = filters.shelterID, pet.shelterID != shelterID { return false }
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

    static let sampleShelters: [Shelter] = {
        let weekdayHours = ["monday": "11:00 AM - 7:00 PM", "tuesday": "11:00 AM - 7:00 PM",
                            "wednesday": "11:00 AM - 7:00 PM", "thursday": "11:00 AM - 7:00 PM",
                            "friday": "11:00 AM - 7:00 PM", "saturday": "10am-5pm", "sunday": "Closed"]
        let everyDay = Dictionary(uniqueKeysWithValues: Shelter.weekdays.map { ($0, "9-5") })
        func shelter(_ number: Int, _ name: String, _ street: String, _ city: String, _ state: String, _ zip: String,
                     email: String? = "adopt@example.com", phone: String? = nil, hours: [String: String]) -> Shelter {
            Shelter(id: "shelter-\(number)", name: name, email: email, phone: phone ?? "(555) 555-02\(number)0",
                    address: "\(street), \(city), \(state) \(zip)", website: URL(string: "https://example.com"),
                    petfinderURL: nil, city: city, state: state, postcode: zip,
                    missionStatement: "\(name) finds loving homes for dogs and cats in the \(city) area. "
                        + "We're run by volunteers and every adoption fee goes straight back into caring for our animals.",
                    hours: hours,
                    adoptionPolicy: "Adopters must be 18+, fill in an application, and meet the pet before adopting.",
                    adoptionURL: URL(string: "https://example.com/adopt"))
        }
        return [
            shelter(1, "Austin Animal Center", "7201 Levander Loop", "Austin", "TX", "78702", hours: weekdayHours),
            shelter(2, "Denver Animal Shelter", "1241 W Bayaud Ave", "Denver", "CO", "80223", hours: everyDay),
            shelter(3, "Portland Pet Rescue", "1067 NE Columbia Blvd", "Portland", "OR", "97211", email: nil, hours: weekdayHours),
            shelter(4, "Chicago Paws Rescue", "2741 S Western Ave", "Chicago", "IL", "60608", phone: nil, hours: [:]),
            shelter(5, "Raleigh Rescue League", "820 Beacon Lake Dr", "Raleigh", "NC", "27610", hours: everyDay),
            shelter(6, "Austin Pets Alive!", "1156 W Cesar Chavez St", "Austin", "TX", "78703", hours: weekdayHours),
            shelter(7, "Denver Dumb Friends League", "2080 S Quebec St", "Denver", "CO", "80231", hours: everyDay),
            shelter(8, "Oregon Humane Society", "1067 NE Columbia Blvd", "Portland", "OR", "97211", hours: weekdayHours),
        ]
    }()

    static let samplePets: [Pet] = {
        let names = ["Biscuit", "Luna", "Milo", "Bella", "Charlie", "Nala", "Oliver", "Daisy", "Max", "Coco",
                     "Leo", "Ruby", "Simba", "Rosie", "Buddy", "Cleo", "Teddy", "Willow", "Rocky", "Pepper",
                     "Ziggy", "Hazel", "Bear", "Olive", "Tucker"]
        let ages = ["Baby", "Young", "Adult", "Senior"]
        let sizes = ["Small", "Medium", "Large"]

        return names.enumerated().map { index, name in
            let isDog = index % 3 != 2
            let breeds = isDog ? dogBreeds : catBreeds
            let shelter = sampleShelters[index % sampleShelters.count]
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
                location: shelter.cityState,
                distance: nil,
                shelterID: shelter.id,
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
