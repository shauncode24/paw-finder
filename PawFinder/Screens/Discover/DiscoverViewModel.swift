import Foundation

/// Drives the Discover tab: search, filters, the pet grid, and the rails.
@MainActor
@Observable
final class DiscoverViewModel {
    enum State {
        case loading
        case loaded
        case empty
        case error(String)
    }

    /// Search text + filters. Changing this triggers a (debounced) reload from the view.
    var filters: PetFilters {
        didSet { saveFilters() }
    }

    private(set) var state: State = .loading
    private(set) var pets: [Pet] = []
    private(set) var isLoadingMore = false
    private(set) var hasMore = false

    // Curated rails, shown when no search or filters are active.
    private(set) var newestPets: [Pet] = []
    private(set) var longestWaitingPets: [Pet] = []

    private let repository: PetRepository
    private var currentPage = 0
    private var loadedFilters: PetFilters?   // filters of what's currently on screen
    private var generation = 0               // bumps on every reload so stale "load more" results are dropped
    private var breeds: [(name: String, species: PetFilters.Species)] = []
    private var railsLoaded = false

    private static let filtersKey = "discoverFilters"

    init(repository: PetRepository) {
        self.repository = repository
        // Restore filters from last time (search text is not saved).
        if let data = UserDefaults.standard.data(forKey: Self.filtersKey),
           let saved = try? JSONDecoder().decode(PetFilters.self, from: data) {
            filters = saved
        } else {
            filters = PetFilters()
        }
    }

    // MARK: - Loading

    /// Called by the view whenever `filters` changes. Waits a moment so typing
    /// in the search box doesn't send a request per keystroke.
    func filtersChanged() async {
        guard filters != loadedFilters else { return }
        if loadedFilters != nil {
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
        }
        await reload(showSkeleton: true)
    }

    /// Loads the first page for the current filters.
    func reload(showSkeleton: Bool = false) async {
        generation += 1
        let requested = filters
        if showSkeleton || pets.isEmpty { state = .loading }

        do {
            let page = try await repository.fetchPets(page: 1, filters: requested)
            guard !Task.isCancelled else { return }
            pets = page.pets
            currentPage = page.currentPage
            hasMore = page.hasMore
            loadedFilters = requested
            state = pets.isEmpty ? .empty : .loaded
        } catch {
            // A newer search replaced this one; not a real error.
            guard !Task.isCancelled else { return }
            state = .error(error.localizedDescription)
        }
    }

    /// Loads the next page. Called when the last card appears.
    func loadMore() async {
        guard hasMore, !isLoadingMore, let loadedFilters else { return }
        let startGeneration = generation
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await repository.fetchPets(page: currentPage + 1, filters: loadedFilters)
            guard startGeneration == generation else { return }
            // Listings can shift between pages, so skip any pet we already have.
            let existing = Set(pets.map(\.id))
            pets += page.pets.filter { !existing.contains($0.id) }
            currentPage = page.currentPage
            hasMore = page.hasMore
        } catch {
            // Keep what's on screen; scrolling to the end again retries.
        }
    }

    func loadRailsIfNeeded() async {
        guard !railsLoaded else { return }
        async let newest = repository.fetchPets(page: 1, filters: PetFilters(sort: .newest))
        async let oldest = repository.fetchPets(page: 1, filters: PetFilters(sort: .longestWaiting))
        // Rails are extras: if they fail, just don't show them.
        newestPets = Array(((try? await newest)?.pets ?? []).prefix(10))
        longestWaitingPets = Array(((try? await oldest)?.pets ?? []).prefix(10))
        railsLoaded = !newestPets.isEmpty || !longestWaitingPets.isEmpty
    }

    // MARK: - Search & filters

    /// Loads breed names for suggestions (for the chosen species, or dogs + cats).
    func loadBreeds() async {
        let speciesList = filters.species.map { [$0] } ?? [.dog, .cat]
        var result: [(name: String, species: PetFilters.Species)] = []
        for species in speciesList {
            let names = (try? await repository.fetchBreeds(for: species)) ?? []
            result += names.map { ($0, species) }
        }
        breeds = result
    }

    /// Breeds matching the search text, shown under the search bar.
    var breedSuggestions: [String] {
        let text = filters.name.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else { return [] }
        return Array(breeds.filter { $0.name.localizedCaseInsensitiveContains(text) }.map(\.name).prefix(6))
    }

    /// Turns a suggestion into a breed filter (and clears the search text).
    func selectBreed(_ name: String) {
        var updated = filters
        updated.breed = name
        updated.species = breeds.first { $0.name == name }?.species ?? filters.species
        updated.name = ""
        filters = updated
    }

    func applyFilters(_ newFilters: PetFilters) {
        var updated = newFilters
        updated.name = filters.name
        filters = updated
    }

    func clearFilters() {
        filters = PetFilters()
    }

    private func saveFilters() {
        if let data = try? JSONEncoder().encode(filters.withoutName) {
            UserDefaults.standard.set(data, forKey: Self.filtersKey)
        }
    }
}
