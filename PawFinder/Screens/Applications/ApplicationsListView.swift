import SwiftUI

/// Profile › My applications: drafts, active, and closed applications.
struct ApplicationsListView: View {
    @Environment(ApplicationsStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        Group {
            if store.applications.isEmpty {
                EmptyStateView(icon: "doc.text", title: "No applications yet",
                               message: "Found a pet you love? Tap \"Apply to adopt\" on their page.",
                               buttonTitle: "Browse pets") { router.selectedTab = .discover }
            } else {
                List {
                    section("Drafts", store.applications.filter { $0.status == .draft })
                    section("In progress", store.applications.filter(\.isActive))
                    section("Closed", store.applications.filter(\.isClosed))
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("My applications")
        .onAppear { store.refresh() }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [AdoptionApplication]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { application in
                    NavigationLink(value: application.status == .draft
                                   ? Route.applicationForm(application.id)
                                   : Route.applicationDetail(application.id)) {
                        row(application)
                    }
                    .listRowBackground(Color.pfSurface)
                }
            }
        }
    }

    private func row(_ application: AdoptionApplication) -> some View {
        HStack(spacing: Spacing.md) {
            Color.clear
                .frame(width: 52, height: 52)
                .overlay { PetPhoto(url: application.pet.thumbnailURL, species: application.pet.species) }
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(application.pet.name)
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                StatusBadge(status: application.status)
                    .font(.pfCaption)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}
