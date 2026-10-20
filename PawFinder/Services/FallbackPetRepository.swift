import Foundation

/// Uses Petfinder, but falls back to the built-in sample pets and shelters
/// when Petfinder can't be used (offline with nothing cached, bad keys,
/// outages, rate limits). The app then still shows something, with a
/// "Showing sample pets" banner (`PetPage.isSample`).
///
/// Sample items have IDs starting with "mock-" / "shelter-", so opening one
/// later always goes to the sample data.
struct FallbackPetRepository: PetRepository {
    let primary: PetRepository
    let sample = MockPetRepository()

    func fetchPets(page: Int, filters: PetFilters) async throws -> PetPage {
        if filters.shelterID.map(Self.isSampleShelter) == true {
            return try await sample.fetchPets(page: page, filters: filters)
        }
        do {
            return try await primary.fetchPets(page: page, filters: filters)
        } catch {
            guard Self.shouldFallBack(error) else { throw error }
            Log.network.notice("Petfinder unavailable (\(error.localizedDescription)); showing sample pets.")
            return try await sample.fetchPets(page: page, filters: filters)
        }
    }

    func fetchPet(id: String) async throws -> Pet {
        if id.hasPrefix("mock-") { return try await sample.fetchPet(id: id) }
        return try await primary.fetchPet(id: id)
    }

    func fetchBreeds(for species: PetFilters.Species) async throws -> [String] {
        do {
            return try await primary.fetchBreeds(for: species)
        } catch {
            guard Self.shouldFallBack(error) else { throw error }
            return try await sample.fetchBreeds(for: species)
        }
    }

    func fetchShelter(id: String) async throws -> Shelter {
        if Self.isSampleShelter(id) { return try await sample.fetchShelter(id: id) }
        return try await primary.fetchShelter(id: id)
    }

    func fetchShelters(near location: String, distance: Int, page: Int) async throws -> ShelterPage {
        do {
            return try await primary.fetchShelters(near: location, distance: distance, page: page)
        } catch {
            guard Self.shouldFallBack(error) else { throw error }
            return try await sample.fetchShelters(near: location, distance: distance, page: page)
        }
    }

    private static func isSampleShelter(_ id: String) -> Bool { id.hasPrefix("shelter-") }

    /// Fall back for "Petfinder can't help right now" errors, not for things
    /// the user can fix (an invalid location) or a pet that's simply gone.
    private static func shouldFallBack(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        switch error as? APIError {
        case .badRequest?, .notFound?: return false
        default: return true
        }
    }
}
