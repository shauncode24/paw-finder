import Foundation

/// Favorites, notes, and collections, saved to a JSON file on the device.
/// Everything is local, so changes show up instantly and work offline.
/// Each favorite's photo is also saved, so it shows offline and in Spotlight.
@MainActor
@Observable
final class FavoritesStore {
    private(set) var favorites: [FavoritePet] = []   // in the user's chosen order
    private(set) var collections: [PetCollection] = []
    private(set) var isRefreshing = false

    private var lastRefresh: Date?
    private let fileURL: URL
    private let indexesSpotlight: Bool

    private struct SavedData: Codable {
        var favorites: [FavoritePet]
        var collections: [PetCollection]
    }

    /// - Parameter fileName: Use a different name for previews so they don't touch real data.
    init(fileName: String = "favorites.json") {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent(fileName)
        indexesSpotlight = fileName == "favorites.json"
        load()
    }

    // MARK: - Favorites

    func isFavorite(_ petID: String) -> Bool {
        favorites.contains { $0.id == petID }
    }

    func toggle(_ pet: Pet) {
        if isFavorite(pet.id) {
            remove(petIDs: [pet.id])
        } else {
            add(pet)
        }
    }

    private func add(_ pet: Pet) {
        favorites.insert(FavoritePet(pet: pet, addedAt: .now), at: 0)
        save(reindex: true)
        Task { await savePhoto(for: pet) }
    }

    /// Unfavorites pets and takes them out of every collection.
    func remove(petIDs: [String]) {
        for favorite in favorites where petIDs.contains(favorite.id) {
            if let url = favorite.localPhotoURL { try? FileManager.default.removeItem(at: url) }
        }
        favorites.removeAll { petIDs.contains($0.id) }
        for index in collections.indices {
            collections[index].petIDs.removeAll { petIDs.contains($0) }
        }
        save(reindex: true)
    }

    func favorite(for petID: String) -> FavoritePet? {
        favorites.first { $0.id == petID }
    }

    /// Replaces the saved copy with fresher data (e.g. from the detail screen).
    func updateSnapshot(_ pet: Pet) {
        guard let index = favorites.firstIndex(where: { $0.id == pet.id }),
              favorites[index].pet != pet else { return }
        favorites[index].pet = pet
        favorites[index].isListed = true
        save(reindex: true)
    }

    func setNote(_ note: String, for petID: String) {
        guard let index = favorites.firstIndex(where: { $0.id == petID }),
              favorites[index].note != note else { return }
        favorites[index].note = note
        save()
    }

    func markStatusSeen(_ petID: String) {
        guard let index = favorites.firstIndex(where: { $0.id == petID }),
              favorites[index].statusChanged else { return }
        favorites[index].statusChanged = false
        save()
    }

    /// Favorites to show: all of them, or just one collection (in that collection's order).
    func favorites(in collectionID: UUID?) -> [FavoritePet] {
        guard let collectionID, let collection = collections.first(where: { $0.id == collectionID }) else {
            return favorites
        }
        return collection.petIDs.compactMap { id in favorites.first { $0.id == id } }
    }

    /// Drag-to-reorder, for "All" or for one collection.
    func move(in collectionID: UUID?, from source: IndexSet, to destination: Int) {
        if let collectionID, let index = collections.firstIndex(where: { $0.id == collectionID }) {
            collections[index].petIDs.move(fromOffsets: source, toOffset: destination)
        } else {
            favorites.move(fromOffsets: source, toOffset: destination)
        }
        save()
    }

    // MARK: - Collections

    @discardableResult
    func createCollection(named name: String) -> PetCollection? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let collection = PetCollection(name: trimmed)
        collections.append(collection)
        save()
        return collection
    }

    func renameCollection(_ collectionID: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        collections[index].name = trimmed
        save()
    }

    func deleteCollection(_ collectionID: UUID) {
        collections.removeAll { $0.id == collectionID }
        save()
    }

    func isPet(_ petID: String, in collectionID: UUID) -> Bool {
        collections.first { $0.id == collectionID }?.petIDs.contains(petID) ?? false
    }

    /// Adds or removes a pet from a collection. Adding also favorites it.
    func toggle(petID: String, in collectionID: UUID, pet: Pet? = nil) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        if collections[index].petIDs.contains(petID) {
            collections[index].petIDs.removeAll { $0 == petID }
            save()
        } else {
            collections[index].petIDs.append(petID)
            if !isFavorite(petID), let pet {
                add(pet)
            } else {
                save()
            }
        }
    }

    func removeFromCollection(_ collectionID: UUID, petIDs: [String]) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        collections[index].petIDs.removeAll { petIDs.contains($0) }
        save()
    }

    // MARK: - Status checks

    /// Re-downloads each favorite to spot adoptions and removed listings.
    /// Runs at most once an hour unless `force` is true (pull to refresh, background).
    /// - Returns: Favorites whose status just changed (for notifications).
    @discardableResult
    func refreshStatuses(using repository: PetRepository, force: Bool = false) async -> [FavoritePet] {
        guard !isRefreshing, !favorites.isEmpty else { return [] }
        if !force, let lastRefresh, Date.now.timeIntervalSince(lastRefresh) < 3600 { return [] }

        isRefreshing = true
        defer { isRefreshing = false }
        var changedIDs: [String] = []

        for petID in favorites.map(\.id) {
            do {
                let fresh = try await repository.fetchPet(id: petID)
                guard let index = favorites.firstIndex(where: { $0.id == petID }) else { continue }
                let old = favorites[index]
                let statusChanged = old.pet.status != nil && fresh.status != old.pet.status
                if (statusChanged || !old.isListed), !old.statusChanged {
                    favorites[index].statusChanged = true
                    changedIDs.append(petID)
                }
                // A single-pet request has no distance, so keep the saved one.
                var updated = fresh
                updated.distance = updated.distance ?? old.pet.distance
                favorites[index].pet = updated
                favorites[index].isListed = true
            } catch APIError.notFound {
                guard let index = favorites.firstIndex(where: { $0.id == petID }) else { continue }
                if favorites[index].isListed {
                    favorites[index].isListed = false
                    favorites[index].statusChanged = true
                    changedIDs.append(petID)
                }
            } catch {
                // Offline or rate-limited: stop, keep what we have, and try again next time.
                break
            }
        }
        lastRefresh = .now
        save(reindex: true)
        return favorites.filter { changedIDs.contains($0.id) }
    }

    // MARK: - Offline photos

    nonisolated static var photosFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FavoritePhotos", isDirectory: true)
    }

    /// Downloads the pet's small photo so it shows offline and in Spotlight.
    private func savePhoto(for pet: Pet) async {
        guard let remoteURL = pet.thumbnailURL ?? pet.photoURLs.first else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            try FileManager.default.createDirectory(at: Self.photosFolder, withIntermediateDirectories: true)
            let fileName = "\(pet.id).jpg"
            try data.write(to: Self.photosFolder.appendingPathComponent(fileName), options: .atomic)

            guard let index = favorites.firstIndex(where: { $0.id == pet.id }) else { return }
            favorites[index].localPhotoFile = fileName
            save(reindex: true)
        } catch {
            Log.storage.error("Couldn't save photo for \(pet.id): \(error.localizedDescription)")
        }
    }

    // MARK: - Saving

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode(SavedData.self, from: data) else { return }
        favorites = saved.favorites
        collections = saved.collections
    }

    /// - Parameter reindex: Also refresh Spotlight (skip for small edits like notes).
    private func save(reindex: Bool = false) {
        let saved = SavedData(favorites: favorites, collections: collections)
        do {
            let data = try JSONEncoder().encode(saved)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.storage.error("Couldn't save favorites: \(error.localizedDescription)")
        }
        if reindex, indexesSpotlight {
            SpotlightIndexer.index(favorites)
        }
    }
}
