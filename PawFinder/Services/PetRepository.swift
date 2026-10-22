import CoreLocation
import SwiftUI

/// Where screens get pets and listers from. Screens only know about this
/// protocol, so the data source can change without touching any UI code.
protocol PetRepository {
    func fetchPets(page: Int, filters: PetFilters) async throws -> PetPage
    func fetchPet(id: String) async throws -> Pet
    /// Breed names for a species, for search suggestions.
    func fetchBreeds(for species: PetFilters.Species) async throws -> [String]
    /// A lister's public profile.
    func fetchShelter(id: String) async throws -> Shelter
    /// Listers with live listings near a place, nearest first.
    /// `location` is a postcode, "City, ST", or "lat,long".
    func fetchShelters(near location: String, distance: Int, page: Int) async throws -> ShelterPage
}

/// The real thing: listings that real people posted, from Firestore.
struct FirestoreListingsRepository: PetRepository {
    let listings: ListingsService
    var pageSize = 20

    func fetchPets(page: Int, filters: PetFilters) async throws -> PetPage {
        try await listings.waitUntilReady()

        // A location filter needs a position to measure from.
        var origin: CLLocationCoordinate2D?
        let place = filters.location.trimmingCharacters(in: .whitespaces)
        if !place.isEmpty {
            origin = await ShelterGeocoder.shared.coordinate(forLocationText: place)
            if origin == nil { throw APIError.badRequest }
        }

        let all = await listings.search(filters: filters, origin: origin)
        let totalPages = max(1, Int((Double(all.count) / Double(pageSize)).rounded(.up)))
        let start = (page - 1) * pageSize
        let slice = start < all.count ? Array(all[start..<min(start + pageSize, all.count)]) : []
        return PetPage(pets: slice, currentPage: page, totalPages: totalPages)
    }

    func fetchPet(id: String) async throws -> Pet {
        try await listings.fetchListing(id: id)
    }

    func fetchBreeds(for species: PetFilters.Species) async throws -> [String] {
        BreedCatalog.breeds(for: species)
    }

    func fetchShelter(id: String) async throws -> Shelter {
        try await ListerDirectory.shared.shelter(id: id)
    }

    func fetchShelters(near location: String, distance: Int, page: Int) async throws -> ShelterPage {
        try await listings.waitUntilReady()
        guard let origin = await ShelterGeocoder.shared.coordinate(forLocationText: location) else {
            throw APIError.badRequest
        }
        let here = CLLocation(latitude: origin.latitude, longitude: origin.longitude)

        let ids = await listings.listerIDs()
        let listers = await ListerDirectory.shared.shelters(ids: ids)

        var nearby: [Shelter] = []
        for lister in listers {
            guard let latitude = lister.latitude, let longitude = lister.longitude else { continue }
            let miles = CLLocation(latitude: latitude, longitude: longitude).distance(from: here) / 1609.34
            guard miles <= Double(distance) else { continue }
            var copy = lister
            copy.distance = miles
            nearby.append(copy)
        }
        nearby.sort { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }

        let pageLength = 25
        let totalPages = max(1, Int((Double(nearby.count) / Double(pageLength)).rounded(.up)))
        let start = (page - 1) * pageLength
        let slice = start < nearby.count ? Array(nearby[start..<min(start + pageLength, nearby.count)]) : []
        return ShelterPage(shelters: slice, currentPage: page, totalPages: totalPages)
    }
}

extension EnvironmentValues {
    /// Use in views: `@Environment(\.petRepository) private var repository`
    /// (Previews fall back to the small built-in sample repository.)
    @Entry var petRepository: PetRepository = MockPetRepository()
}
