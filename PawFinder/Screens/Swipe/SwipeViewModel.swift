import Foundation

/// A stack of pets to swipe through. Like = favorite, Pass = skip (remembered,
/// so it doesn't come back), Super-like = favorite + add to "Top picks".
/// Undo reverses the last swipe.
@MainActor
@Observable
final class SwipeViewModel {
    enum Action {
        case like, pass, superLike
    }

    private(set) var queue: [Pet] = []      // first = top card
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var reachedEnd = false
    private(set) var history: [(pet: Pet, action: Action, wasFavorite: Bool)] = []

    private let repository: PetRepository
    private let filters: PetFilters
    private var page = 0
    private var hasMore = true
    private var passedIDs: Set<String>
    /// After "Show passed pets again" the stack also includes pets already liked.
    private var showEverything = false

    private static let passedKey = "swipePassedPetIDs"
    static let topPicksName = "Top picks"

    init(repository: PetRepository, filters: PetFilters) {
        self.repository = repository
        self.filters = filters
        passedIDs = Set(UserDefaults.standard.stringArray(forKey: Self.passedKey) ?? [])
    }

    var canUndo: Bool { !history.isEmpty }

    /// Loads more cards when fewer than 5 are left, so the stack never runs dry
    /// mid-swipe (and the next photos load while the user is still swiping).
    func loadMoreIfNeeded(skipping favorites: FavoritesStore) async {
        guard queue.count < 5, hasMore, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Skip pets already liked or passed; keep paging until we find some.
        var attempts = 0
        while queue.count < 5, hasMore, attempts < 3 {
            attempts += 1
            do {
                let result = try await repository.fetchPets(page: page + 1, filters: filters)
                page = result.currentPage
                hasMore = result.hasMore
                let shown = Set(queue.map(\.id))
                let everything = showEverything
                let fresh: [Pet] = result.pets.filter { pet in
                    if shown.contains(pet.id) { return false }
                    if everything { return true }
                    return !passedIDs.contains(pet.id) && !favorites.isFavorite(pet.id)
                }
                queue += fresh
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        reachedEnd = queue.isEmpty && !hasMore
    }

    func swipe(_ action: Action, favorites: FavoritesStore) {
        guard let pet = queue.first else { return }
        queue.removeFirst()
        let wasFavorite = favorites.isFavorite(pet.id)
        history.append((pet, action, wasFavorite))

        switch action {
        case .pass:
            passedIDs.insert(pet.id)
            savePassed()
        case .like:
            if !wasFavorite { favorites.toggle(pet) }
        case .superLike:
            if !wasFavorite { favorites.toggle(pet) }
            let topPicks = favorites.collections.first { $0.name == Self.topPicksName }
                ?? favorites.createCollection(named: Self.topPicksName)
            if let topPicks, !favorites.isPet(pet.id, in: topPicks.id) {
                favorites.toggle(petID: pet.id, in: topPicks.id, pet: pet)
            }
        }
    }

    func undo(favorites: FavoritesStore) {
        guard let last = history.popLast() else { return }
        switch last.action {
        case .pass:
            passedIDs.remove(last.pet.id)
            savePassed()
        case .like, .superLike:
            if !last.wasFavorite, favorites.isFavorite(last.pet.id) { favorites.toggle(last.pet) }
        }
        queue.insert(last.pet, at: 0)
        reachedEnd = false
    }

    /// Lets passed pets show up again.
    func resetPassed() async {
        passedIDs = []
        savePassed()
        showEverything = true      // pets you liked come back too, so the stack is never empty by surprise
        queue = []
        history = []
        page = 0
        hasMore = true
        reachedEnd = false
        errorMessage = nil
    }

    private func savePassed() {
        // Keep the list from growing forever.
        UserDefaults.standard.set(Array(passedIDs.suffix(1000)), forKey: Self.passedKey)
    }
}
