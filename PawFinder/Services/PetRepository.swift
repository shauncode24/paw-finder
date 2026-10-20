import SwiftUI

/// Where screens get pets from. Screens only know about this protocol, so
/// we can swap real data for mock data without changing any UI code.
protocol PetRepository {
    func fetchPets(page: Int, filters: PetFilters) async throws -> PetPage
    func fetchPet(id: String) async throws -> Pet
    /// All breed names for a species, for search suggestions.
    func fetchBreeds(for species: PetFilters.Species) async throws -> [String]
    func fetchShelter(id: String) async throws -> Shelter
}

/// Real data from Petfinder.
struct RemotePetRepository: PetRepository {
    let client: PetfinderClient
    var pageSize = 20

    func fetchPets(page: Int, filters: PetFilters) async throws -> PetPage {
        var query = filters.queryItems
        query["status"] = "adoptable"

        // The cache key leaves out page/limit, so each search has one saved first page.
        let cacheKey = query
        query["page"] = String(page)
        query["limit"] = String(pageSize)

        do {
            let response: PetfinderAnimalsResponse = try await client.get("animals", query: query)
            let pets = response.animals.map { $0.toPet() }
            if page == 1 { PetCache.save(pets, for: cacheKey) }
            return PetPage(
                pets: pets,
                currentPage: response.pagination.currentPage,
                totalPages: response.pagination.totalPages
            )
        } catch APIError.offline where page == 1 {
            // Offline: show the last saved results for this search, if any.
            guard let cached = PetCache.load(for: cacheKey) else { throw APIError.offline }
            return PetPage(pets: cached.pets, currentPage: 1, totalPages: 1, cachedAt: cached.savedAt)
        }
    }

    func fetchPet(id: String) async throws -> Pet {
        let response: PetfinderAnimalResponse = try await client.get("animals/\(id)")
        return response.animal.toPet()
    }

    func fetchBreeds(for species: PetFilters.Species) async throws -> [String] {
        let response: PetfinderBreedsResponse = try await client.get("types/\(species.rawValue.lowercased())/breeds")
        return response.breeds.map(\.name)
    }

    func fetchShelter(id: String) async throws -> Shelter {
        let response: PetfinderOrganizationResponse = try await client.get("organizations/\(id)")
        return response.organization.toShelter()
    }
}

/// Picks the real repository if Petfinder keys are filled in, otherwise mock data.
enum PetRepositoryFactory {
    static func make() -> PetRepository {
        guard Secrets.hasPetfinderKeys else {
            Log.app.info("No Petfinder keys in Secrets.plist, so the app is using mock data.")
            return MockPetRepository()
        }
        let client = PetfinderClient(apiKey: Secrets.petfinderAPIKey, apiSecret: Secrets.petfinderAPISecret)
        return RemotePetRepository(client: client)
    }
}

extension EnvironmentValues {
    /// Use in views: `@Environment(\.petRepository) private var repository`
    @Entry var petRepository: PetRepository = MockPetRepository()
}
