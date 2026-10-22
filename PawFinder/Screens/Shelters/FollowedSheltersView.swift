import SwiftUI

/// Profile › Followed shelters. Swipe to unfollow.
struct FollowedSheltersView: View {
    @Environment(FollowedSheltersStore.self) private var followed
    @Environment(Router.self) private var router

    var body: some View {
        Group {
            if followed.shelters.isEmpty {
                EmptyStateView(icon: "star", title: "Not following anyone yet",
                               message: "Follow a lister from their page to hear about new pets they post.",
                               buttonTitle: "Browse pets") { router.selectedTab = .map }
            } else {
                List {
                    Section {
                        ForEach(followed.shelters) { shelter in
                            NavigationLink(value: Route.shelter(id: shelter.id)) {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(shelter.name)
                                        .font(.pfHeadline)
                                        .foregroundStyle(Color.pfTextPrimary)
                                    if !shelter.cityState.isEmpty {
                                        Text(shelter.cityState)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.pfTextSecondary)
                                    }
                                }
                            }
                            .listRowBackground(Color.pfSurface)
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { followed.shelters[$0].id }
                            ids.forEach(followed.unfollow)
                        }
                    } footer: {
                        Text("We check now and then for newly listed pets and send a notification.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("Listers I follow")
    }
}
