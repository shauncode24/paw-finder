import SwiftUI

@main
struct PawFinderApp: App {
    @State private var router = Router()
    @State private var recentlyViewed = RecentlyViewedStore()
    @State private var favorites = FavoritesStore()
    private let petRepository = PetRepositoryFactory.make()

    init() {
        // Bigger shared cache so pet photos (loaded by AsyncImage) are kept
        // in memory and on disk instead of re-downloaded while scrolling.
        URLCache.shared = URLCache(memoryCapacity: 50_000_000, diskCapacity: 200_000_000)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(recentlyViewed)
                .environment(favorites)
                .environment(\.petRepository, petRepository)
                .tint(.pfBrandPrimary)
        }
    }
}
