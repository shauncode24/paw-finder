import Foundation

/// Shelters the user follows, saved in UserDefaults. The background check
/// looks for newly listed pets at these shelters and sends a notification.
@MainActor
@Observable
final class FollowedSheltersStore {
    struct FollowedShelter: Codable, Identifiable, Hashable {
        let id: String
        var name: String
        var cityState: String
        let followedAt: Date
        /// Newest listing we've already told the user about.
        var lastSeenListing: Date?
    }

    /// One shelter's new pets, for a notification.
    struct NewArrivals {
        let shelter: FollowedShelter
        let pets: [Pet]
    }

    private(set) var shelters: [FollowedShelter] = []
    private let key = "followedShelters"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([FollowedShelter].self, from: data) {
            shelters = saved
        }
    }

    func isFollowing(_ shelterID: String) -> Bool {
        shelters.contains { $0.id == shelterID }
    }

    func toggle(_ shelter: Shelter) {
        if isFollowing(shelter.id) {
            unfollow(shelter.id)
        } else {
            shelters.append(FollowedShelter(id: shelter.id, name: shelter.name, cityState: shelter.cityState,
                                            followedAt: .now, lastSeenListing: .now))
            save()
        }
    }

    func unfollow(_ shelterID: String) {
        shelters.removeAll { $0.id == shelterID }
        save()
    }

    /// Checks each followed shelter for pets listed since we last looked.
    func checkNewArrivals(using repository: PetRepository) async -> [NewArrivals] {
        var results: [NewArrivals] = []
        for shelter in shelters {
            var filters = PetFilters()
            filters.shelterID = shelter.id
            filters.sort = .newest
            guard let page = try? await repository.fetchPets(page: 1, filters: filters) else { continue }

            let since = shelter.lastSeenListing ?? shelter.followedAt
            let newPets = page.pets.filter { ($0.publishedAt ?? .distantPast) > since }
            guard !newPets.isEmpty, let index = shelters.firstIndex(where: { $0.id == shelter.id }) else { continue }

            shelters[index].lastSeenListing = newPets.compactMap(\.publishedAt).max()
            results.append(NewArrivals(shelter: shelters[index], pets: newPets))
        }
        save()
        return results
    }

    private func save() {
        if let data = try? JSONEncoder().encode(shelters) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
