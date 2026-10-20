import CoreSpotlight
import SwiftUI

@main
struct PawFinderApp: App {
    @State private var router: Router
    @State private var recentlyViewed = RecentlyViewedStore()
    @State private var favorites = FavoritesStore()
    @State private var locationService = LocationService()
    @State private var followedShelters = FollowedSheltersStore()
    @AppStorage("appearance") private var appearance: AppearanceSetting = .system
    @Environment(\.scenePhase) private var scenePhase
    private let petRepository = PetRepositoryFactory.make()

    init() {
        // Bigger shared cache so pet photos (loaded by AsyncImage) are kept
        // in memory and on disk instead of re-downloaded while scrolling.
        URLCache.shared = URLCache(memoryCapacity: 50_000_000, diskCapacity: 200_000_000)

        let router = Router()
        _router = State(initialValue: router)
        // Tapping a notification opens its deep link.
        NotificationManager.shared.onOpenURL = { url in router.handle(url) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(recentlyViewed)
                .environment(favorites)
                .environment(locationService)
                .environment(followedShelters)
                .environment(\.petRepository, petRepository)
                .tint(.pfBrandPrimary)
                .preferredColorScheme(appearance.colorScheme)
                .onOpenURL { url in router.handle(url) }
                // Tapping a favorite in iPhone search (Spotlight).
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    if let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                        router.open(.petID(id), in: .favorites)
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { BackgroundRefresh.schedule() }
        }
        // iOS wakes the app in the background now and then: check favorites for
        // adoptions and followed shelters for new pets.
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await checkFavoritesInBackground()
        }
    }

    private func checkFavoritesInBackground() async {
        BackgroundRefresh.schedule()   // ask for the next one
        let changed = await favorites.refreshStatuses(using: petRepository, force: true)
        await NotificationManager.shared.notifyStatusChanges(changed)
        let arrivals = await followedShelters.checkNewArrivals(using: petRepository)
        await NotificationManager.shared.notifyNewArrivals(arrivals)
    }
}
