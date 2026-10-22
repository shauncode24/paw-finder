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
                MapHomeView(repository: petRepository)
            case .identify:
                BreedsHubView()
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
        case .messages:
            ConversationsListView()
        case .conversation(let id):
            ChatView(conversationID: id)
        case .listerSetup:
            ListerSetupView()
        case .myListings:
            MyListingsView()
        case .newListing:
            ListingFormView()
        case .editListing(let id):
            ListingFormView(editingID: id)
        case .receivedApplications:
            ReceivedApplicationsView()
        case .receivedApplication(let id):
            ReceivedApplicationDetailView(applicationID: id)
        case .savedSearches:
            SavedSearchesView()
        case .notificationSettings:
            NotificationSettingsView()
        case .swipe(let filters):
            SwipeView(repository: petRepository, filters: filters)
        case .compare(let pets):
            CompareView(pets: pets)
        case .careHub:
            CareHubView()
        case .careArticle(let id):
            if let article = CareContent.articles.first(where: { $0.id == id }) {
                CareArticleView(article: article)
            }
        case .breedGuide(let name):
            if let guide = CareContent.breedGuides.first(where: { $0.name == name }) {
                BreedGuideView(guide: guide)
            }
        case .help:
            HelpView()
        case .about:
            AboutView()
        case .privacyPolicy:
            LegalTextView.privacy
        case .terms:
            LegalTextView.terms
        case .careChecklist(let id):
            if let checklist = CareContent.checklists.first(where: { $0.id == id }) {
                CareChecklistView(checklist: checklist)
            }
        case .meetupMap(let meetup):
            MeetupMapView(meetup: meetup)
        case .nearbyPlaces:
            NearbyPlacesView()
        case .designSystem:
            DesignSystemPreviewView()
        }
    }
}
