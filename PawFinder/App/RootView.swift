import SwiftUI

/// The tab bar. Each tab has its own NavigationStack driven by the Router.
struct RootView: View {
    @Environment(Router.self) private var router

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
}
