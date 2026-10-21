import Foundation

/// Saved Discover searches (UserDefaults). The background check looks for
/// pets listed since last time and sends "3 new pets match …" notifications.
@MainActor
@Observable
final class SavedSearchesStore {
    struct NewMatches {
        let search: SavedSearch
        let pets: [Pet]
    }

    private(set) var searches: [SavedSearch] = []
    private let key = "savedSearches"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([SavedSearch].self, from: data) {
            searches = saved
        }
    }

    var newMatchTotal: Int { searches.map(\.newMatchCount).reduce(0, +) }

    func search(_ id: UUID) -> SavedSearch? {
        searches.first { $0.id == id }
    }

    /// The saved search with exactly these filters, if any.
    func search(matching filters: PetFilters) -> SavedSearch? {
        searches.first { $0.filters == filters }
    }

    @discardableResult
    func add(name: String, filters: PetFilters, alertsOn: Bool) -> SavedSearch {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let search = SavedSearch(name: trimmed.isEmpty ? SavedSearch.suggestedName(for: filters) : trimmed,
                                 filters: filters, alertsOn: alertsOn)
        searches.insert(search, at: 0)
        save()
        return search
    }

    func removeAll() {
        searches = []
        save()
    }

    func delete(_ id: UUID) {
        searches.removeAll { $0.id == id }
        save()
    }

    func setAlerts(_ on: Bool, for id: UUID) {
        guard let index = searches.firstIndex(where: { $0.id == id }) else { return }
        searches[index].alertsOn = on
        save()
    }

    func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let index = searches.firstIndex(where: { $0.id == id }) else { return }
        searches[index].name = trimmed
        save()
    }

    /// The user opened this search: clear its "new" count.
    func markSeen(_ id: UUID) {
        guard let index = searches.firstIndex(where: { $0.id == id }), searches[index].newMatchCount > 0 else { return }
        searches[index].newMatchCount = 0
        save()
    }

    /// Looks for pets listed since the last check, for searches with alerts on.
    func checkNewMatches(using repository: PetRepository) async -> [NewMatches] {
        var results: [NewMatches] = []
        for search in searches where search.alertsOn {
            var filters = search.filters
            filters.sort = .newest
            guard let page = try? await repository.fetchPets(page: 1, filters: filters) else { continue }

            let newPets = page.pets.filter { ($0.publishedAt ?? .distantPast) > search.lastSeenListing }
            guard !newPets.isEmpty, let index = searches.firstIndex(where: { $0.id == search.id }) else { continue }
            searches[index].lastSeenListing = newPets.compactMap(\.publishedAt).max() ?? .now
            searches[index].newMatchCount += newPets.count
            results.append(NewMatches(search: searches[index], pets: newPets))
        }
        save()
        return results
    }

    private func save() {
        if let data = try? JSONEncoder().encode(searches) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
