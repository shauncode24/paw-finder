import CoreSpotlight
import SwiftUI

@main
struct PawFinderApp: App {
    @State private var router: Router
    @State private var recentlyViewed = RecentlyViewedStore()
    @State private var favorites = FavoritesStore()
    @State private var locationService = LocationService()
    @State private var followedShelters = FollowedSheltersStore()
    @State private var auth: AuthManager
    @State private var profileStore = ProfileStore()
    @State private var applications = ApplicationsStore()
    @AppStorage("appearance") private var appearance: AppearanceSetting = .system
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    private let petRepository = PetRepositoryFactory.make()

    init() {
        // Bigger shared cache so pet photos (loaded by AsyncImage) are kept
        // in memory and on disk instead of re-downloaded while scrolling.
        URLCache.shared = URLCache(memoryCapacity: 50_000_000, diskCapacity: 200_000_000)

        // Accounts: only turns on if GoogleService-Info.plist is in the app.
        AuthManager.configureFirebase()
        _auth = State(initialValue: AuthManager())

        let router = Router()
        _router = State(initialValue: router)
        // Tapping a notification opens its deep link.
        NotificationManager.shared.onOpenURL = { url in router.handle(url) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // First launch: welcome → account → lifestyle → location.
                .fullScreenCover(isPresented: Binding(get: { !hasCompletedOnboarding }, set: { _ in })) {
                    OnboardingView { hasCompletedOnboarding = true }
                }
                // Load the right profile when someone signs in or out.
                .onChange(of: auth.user?.id, initial: true) { _, userID in
                    profileStore.switchUser(to: userID, suggestedName: auth.user?.displayName)
                }
                .environment(router)
                .environment(auth)
                .environment(profileStore)
                .environment(applications)
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
            switch phase {
            case .background: BackgroundRefresh.schedule()
            case .active: applications.refresh()   // apply any simulated shelter replies
            default: break
            }
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
        applications.refresh()
    }
}
