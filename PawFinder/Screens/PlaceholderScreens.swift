import SwiftUI

/// Home screen for each tab. Placeholders are replaced as each phase is built.
struct TabHomeView: View {
    let tab: AppTab
    @Environment(\.petRepository) private var petRepository

    var body: some View {
        Group {
            switch tab {
            case .discover:
                DiscoverView(repository: petRepository)
            case .map:
                EmptyStateView(icon: "map", title: "Shelters near you", message: "Coming in Phase 5.")
            case .identify:
                EmptyStateView(icon: "camera.viewfinder", title: "Identify a breed", message: "Coming in Phase 6.")
            case .favorites:
                FavoritesView()
            case .profile:
                List {
                    NavigationLink("Design system", value: Route.designSystem)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pfBackground)
        .navigationTitle(tab.title)
    }
}

/// Shows the screen for a Route.
struct RouteView: View {
    let route: Route
    @Environment(\.petRepository) private var petRepository

    var body: some View {
        switch route {
        case .petDetail(let pet):
            PetDetailView(pet: pet, repository: petRepository)
        case .shelter(let id):
            EmptyStateView(icon: "house.fill", title: "Shelter", message: "Shelter \(id)")
                .navigationTitle("Shelter")
        case .designSystem:
            DesignSystemPreviewView()
        }
    }
}
