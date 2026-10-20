import SwiftUI

/// The tab bar. Each tab has its own NavigationStack driven by the Router.
struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(MessagesStore.self) private var messages

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                NavigationStack(path: $router.paths[tab, default: []]) {
                    TabHomeView(tab: tab)
                        .navigationDestination(for: Route.self) { route in
                            RouteView(route: route)
                        }
                }
                .tabItem { Label(tab.title, systemImage: tab.icon) }
                .tag(tab)
                // Unread messages live under Profile.
                .badge(tab == .profile ? messages.unreadCount : 0)
            }
        }
        // Our "turn on notifications?" explanation, before the system prompt.
        .sheet(isPresented: Binding(
            get: { NotificationManager.shared.primingCategory != nil },
            set: { isShown in if !isShown, NotificationManager.shared.primingCategory != nil { NotificationManager.shared.declinePriming() } }
        )) {
            if let category = NotificationManager.shared.primingCategory {
                NotificationPrimingView(category: category)
                    .presentationDetents([.large])
            }
        }
    }
}

#Preview {
    RootView()
        .environment(Router())
        .environment(RecentlyViewedStore())
        .environment(FavoritesStore(fileName: "preview-favorites.json"))
        .environment(LocationService())
        .environment(FollowedSheltersStore())
        .environment(AuthManager())
        .environment(ProfileStore())
        .environment(ApplicationsStore())
        .environment(MessagesStore())
        .environment(NetworkMonitor())
        .environment(SavedSearchesStore())
}
