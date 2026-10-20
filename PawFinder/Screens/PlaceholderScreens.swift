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
                ShelterMapView(repository: petRepository)
            case .identify:
                EmptyStateView(icon: "camera.viewfinder", title: "Identify a breed", message: "Coming in Phase 6.")
            case .favorites:
                FavoritesView()
            case .profile:
                ProfileView()
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
        case .petID(let id):
            PetLoaderView(petID: id)
        case .settings:
            SettingsView()
        case .shelter(let id):
            ShelterProfileView(shelterID: id, repository: petRepository)
        case .followedShelters:
            FollowedSheltersView()
        case .editProfile:
            EditProfileView()
        case .lifestyle:
            LifestyleQuestionnaireView(popsOnSave: true)
                .navigationTitle("Your lifestyle")
        case .account:
            AccountView()
        case .applications:
            ApplicationsListView()
        case .applicationForm(let id):
            ApplicationFormView(applicationID: id)
        case .applicationDetail(let id):
            ApplicationDetailView(applicationID: id)
        case .designSystem:
            DesignSystemPreviewView()
        }
    }
}
