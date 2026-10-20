import Foundation

/// Remembers the last few pets the user opened (saved in UserDefaults).
@Observable
final class RecentlyViewedStore {
    private(set) var pets: [Pet] = []

    private let key = "recentlyViewedPets"
    private let limit = 10

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([Pet].self, from: data) {
            pets = saved
        }
    }

    func add(_ pet: Pet) {
        pets.removeAll { $0.id == pet.id }
        pets.insert(pet, at: 0)
        pets = Array(pets.prefix(limit))
        save()
    }

    func clear() {
        pets = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pets) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
