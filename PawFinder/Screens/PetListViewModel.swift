import Foundation

/// Loads pets page by page for PetListView.
@MainActor
@Observable
final class PetListViewModel {
    enum State {
        case loading
        case loaded
        case empty
        case error(String)
    }

    private(set) var state: State = .loading
    private(set) var pets: [Pet] = []
    private(set) var isLoadingMore = false
    private(set) var hasMore = false

    private let repository: PetRepository
    private var currentPage = 0

    init(repository: PetRepository) {
        self.repository = repository
    }

    /// Loads (or reloads) the first page.
    func load() async {
        if pets.isEmpty { state = .loading }
        do {
            let page = try await repository.fetchPets(page: 1, type: nil)
            pets = page.pets
            currentPage = page.currentPage
            hasMore = page.hasMore
            state = pets.isEmpty ? .empty : .loaded
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Loads the next page. Call when the last row appears.
    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await repository.fetchPets(page: currentPage + 1, type: nil)
            // Listings can shift between pages, so skip any pet we already have.
            let existing = Set(pets.map(\.id))
            pets += page.pets.filter { !existing.contains($0.id) }
            currentPage = page.currentPage
            hasMore = page.hasMore
        } catch {
            // Keep what's on screen; the user can scroll again to retry.
            hasMore = true
        }
    }
}
