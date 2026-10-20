import CoreLocation
import Foundation

/// Loads a shelter, its map location, and its adoptable pets.
@MainActor
@Observable
final class ShelterProfileViewModel {
    enum State {
        case loading
        case loaded(Shelter)
        case error(String)
    }

    let shelterID: String
    private(set) var state: State = .loading
    private(set) var coordinate: CLLocationCoordinate2D?

    private(set) var pets: [Pet] = []
    private(set) var isLoadingPets = false
    private(set) var hasMorePets = false
    private var petsPage = 0

    private let repository: PetRepository

    init(shelterID: String, repository: PetRepository) {
        self.shelterID = shelterID
        self.repository = repository
    }

    func load() async {
        if case .loaded = state { return }
        state = .loading
        do {
            let shelter = try await repository.fetchShelter(id: shelterID)
            state = .loaded(shelter)
            async let pets: Void = loadMorePets()
            coordinate = await ShelterGeocoder.shared.coordinate(for: shelter)
            await pets
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func loadMorePets() async {
        guard !isLoadingPets else { return }
        isLoadingPets = true
        defer { isLoadingPets = false }

        var filters = PetFilters()
        filters.shelterID = shelterID
        guard let page = try? await repository.fetchPets(page: petsPage + 1, filters: filters) else { return }
        let existing = Set(pets.map(\.id))
        pets += page.pets.filter { !existing.contains($0.id) }
        petsPage = page.currentPage
        hasMorePets = page.hasMore
    }
}
