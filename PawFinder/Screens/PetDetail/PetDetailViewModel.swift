import CoreLocation
import Foundation

/// Loads the extra things the detail screen needs: the shelter (plus its map
/// location) and similar pets. The pet itself is passed in from the grid.
@MainActor
@Observable
final class PetDetailViewModel {
    enum ShelterState {
        case loading
        case loaded(Shelter)
        case failed
    }

    let pet: Pet
    private(set) var shelterState: ShelterState = .loading
    private(set) var shelterCoordinate: CLLocationCoordinate2D?
    private(set) var similarPets: [Pet] = []

    private let repository: PetRepository

    init(pet: Pet, repository: PetRepository) {
        self.pet = pet
        self.repository = repository
    }

    func load() async {
        async let shelterTask: Void = loadShelter()
        async let similarTask: Void = loadSimilarPets()
        _ = await (shelterTask, similarTask)
    }

    func loadShelter() async {
        shelterState = .loading
        do {
            let shelter = try await repository.fetchShelter(id: pet.shelterID)
            shelterState = .loaded(shelter)
            shelterCoordinate = await Self.coordinate(for: shelter.address)
        } catch {
            shelterState = .failed
        }
    }

    /// Same species and breed first; if that finds too few, any pet of the same species.
    private func loadSimilarPets() async {
        let species = PetFilters.Species(rawValue: pet.species)
        var filters = PetFilters(species: species, breed: species == nil ? nil : pet.primaryBreed)

        var results = (try? await repository.fetchPets(page: 1, filters: filters).pets) ?? []
        results.removeAll { $0.id == pet.id }

        if results.count < 3, filters.breed != nil {
            filters.breed = nil
            let more = (try? await repository.fetchPets(page: 1, filters: filters).pets) ?? []
            let existing = Set(results.map(\.id))
            results += more.filter { $0.id != pet.id && !existing.contains($0.id) }
        }
        similarPets = Array(results.prefix(10))
    }

    /// Turns a street address into map coordinates using Apple's geocoder.
    private static func coordinate(for address: String) async -> CLLocationCoordinate2D? {
        guard !address.isEmpty else { return nil }
        let placemarks = try? await CLGeocoder().geocodeAddressString(address)
        return placemarks?.first?.location?.coordinate
    }
}
