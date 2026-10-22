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
    @State private var messages = MessagesStore()
    @State private var network = NetworkMonitor()
    @State private var savedSearches = SavedSearchesStore()
    @State private var careChecklists = CareChecklistStore()
    @State private var listings: ListingsService
    @State private var listerProfile = ListerProfileStore()
    @AppStorage("appearance") private var appearance: AppearanceSetting = .system
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    private let petRepository: PetRepository

    init() {
        // Firebase first: accounts, listings, chats, and applications all depend on it.
        // It only turns on if GoogleService-Info.plist is in the app (see docs/SETUP.md).
        AuthManager.configureFirebase()
        _auth = State(initialValue: AuthManager())

        // Listings are a live feed from Firestore; the repository the screens use reads from it.
        let listingsService = ListingsService()
        _listings = State(initialValue: listingsService)
        petRepository = FirestoreListingsRepository(listings: listingsService)

        let router = Router()
        _router = State(initialValue: router)
        // Notification taps and Siri/Shortcuts open deep links through the router.
        NotificationManager.shared.onOpenURL = { url in router.handle(url) }
        AppLinks.handler = { url in router.handle(url) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // First launch: welcome → account → lifestyle → location.
                .fullScreenCover(isPresented: Binding(get: { !hasCompletedOnboarding }, set: { _ in })) {
                    OnboardingView { hasCompletedOnboarding = true }
                }
                // Whoever signs in or out: load their profile, chats, applications, and listings.
                .onChange(of: auth.user?.id, initial: true) { _, userID in
                    profileStore.switchUser(to: userID, suggestedName: auth.user?.displayName)
                    messages.start(for: userID)
                    applications.start(for: userID)
                    listerProfile.start(for: userID)
                    listings.startMine(for: userID)
                }
                .environment(router)
                .environment(auth)
                .environment(profileStore)
                .environment(applications)
                .environment(messages)
                .environment(network)
                .environment(savedSearches)
                .environment(careChecklists)
                .environment(listings)
                .environment(listerProfile)
                // The number on the app icon: unread messages, new applications, changed favorites, new search matches.
                .onChange(of: badgeCount, initial: true) { _, count in
                    NotificationManager.shared.updateBadge(count)
                }
                .environment(recentlyViewed)
                .environment(favorites)
                .environment(locationService)
                .environment(followedShelters)
                .environment(\.petRepository, petRepository)
                .tint(.pfBrandPrimary)
                .preferredColorScheme(appearance.colorScheme)
                .onOpenURL { url in router.handle(url) }
                // Handoff from another device.
                .onContinueUserActivity("com.pawfinder.viewPet") { activity in
                    if let id = activity.userInfo?["petID"] as? String {
                        router.open(.petID(id), in: .discover)
                    }
                }
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
        // iOS wakes the app in the background now and then. Live listeners stop when the
        // app is closed, so this is when we look for anything that happened meanwhile.
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await checkInBackground()
        }
    }

    private func checkInBackground() async {
        BackgroundRefresh.schedule()   // ask for the next one
        let changed = await favorites.refreshStatuses(using: petRepository, force: true)
        await NotificationManager.shared.notifyStatusChanges(changed)
        let arrivals = await followedShelters.checkNewArrivals(using: petRepository)
        await NotificationManager.shared.notifyNewArrivals(arrivals)
        let matches = await savedSearches.checkNewMatches(using: petRepository)
        await NotificationManager.shared.notifySavedSearchMatches(matches)
        await messages.backgroundCheck()
        await applications.backgroundCheck()
        NotificationManager.shared.updateBadge(badgeCount)
    }

    private var badgeCount: Int {
        let changedFavorites = favorites.favorites.filter(\.statusChanged).count
        return messages.unreadCount + applications.newReceivedCount + changedFavorites + savedSearches.newMatchTotal
    }
}
