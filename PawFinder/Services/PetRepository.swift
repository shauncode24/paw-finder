import SwiftUI

/// Where screens get pets from. Screens only know about this protocol, so
/// we can swap real data for mock data without changing any UI code.
protocol PetRepository {
    /// - Parameter type: Petfinder animal type, e.g. "dog" or "cat". nil = all.
    func fetchPets(page: Int, type: String?) async throws -> PetPage
    func fetchPet(id: String) async throws -> Pet
}

/// Real data from Petfinder.
struct RemotePetRepository: PetRepository {
    let client: PetfinderClient
    var pageSize = 20

    func fetchPets(page: Int, type: String?) async throws -> PetPage {
        var query = ["page": String(page), "limit": String(pageSize), "status": "adoptable"]
        if let type { query["type"] = type }

        let response: PetfinderAnimalsResponse = try await client.get("animals", query: query)
        return PetPage(
            pets: response.animals.map { $0.toPet() },
            currentPage: response.pagination.currentPage,
            totalPages: response.pagination.totalPages
        )
    }

    func fetchPet(id: String) async throws -> Pet {
        let response: PetfinderAnimalResponse = try await client.get("animals/\(id)")
        return response.animal.toPet()
    }
}

/// Picks the real repository if Petfinder keys are filled in, otherwise mock data.
enum PetRepositoryFactory {
    static func make() -> PetRepository {
        guard Secrets.hasPetfinderKeys else {
            print("No Petfinder keys in Secrets.plist, so the app is using mock data.")
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
