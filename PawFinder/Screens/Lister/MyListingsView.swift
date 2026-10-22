import SwiftUI

/// Profile › My listings: every pet you've listed, with its status, and quick
/// actions (edit, mark pending/adopted/available, delete).
struct MyListingsView: View {
    @Environment(ListingsService.self) private var listings
    @Environment(ApplicationsStore.self) private var applications
    @Environment(Router.self) private var router

    @State private var errorMessage: String?
    @State private var petToDelete: Pet?

    var body: some View {
        Group {
            if listings.myListings.isEmpty {
                EmptyStateView(icon: "pawprint", title: "No listings yet",
                               message: "List a pet who needs a home. Adopters nearby will see them in Discover right away.",
                               buttonTitle: "List a pet") { router.push(.newListing) }
            } else {
                List {
                    Section {
                        ForEach(listings.myListings) { pet in
                            NavigationLink(value: Route.editListing(pet.id)) {
                                row(pet)
                            }
                            .listRowBackground(Color.pfSurface)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) { petToDelete = pet }
                            }
                            .contextMenu { statusMenu(for: pet) }
                        }
                    } footer: {
                        Text("Tap a pet to edit it. Long-press to change its status quickly.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("My listings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.push(.newListing)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add a listing")
            }
        }
        .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil },
                                                           set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("Delete \(petToDelete?.name ?? "this listing")?",
                            isPresented: Binding(get: { petToDelete != nil }, set: { if !$0 { petToDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete listing", role: .destructive) {
                if let pet = petToDelete { delete(pet) }
            }
        } message: {
            Text("It will disappear for everyone. This can't be undone.")
        }
    }

    private func row(_ pet: Pet) -> some View {
        let status = ListingStatus(petStatus: pet.status)
        let interested = applications.received.filter { $0.listingID == pet.id }.count
        return HStack(spacing: Spacing.md) {
            Color.clear
                .frame(width: 60, height: 60)
                .overlay { PetPhoto(url: pet.thumbnailURL, species: pet.species) }
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(pet.name)
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                Text(pet.breed)
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
                    .lineLimit(1)
                HStack(spacing: Spacing.sm) {
                    Text(status.title)
                        .font(.pfCaption.weight(.semibold))
                        .foregroundStyle(color(for: status))
                    if interested > 0 {
                        Label("\(interested)", systemImage: "doc.text")
                            .font(.pfCaption)
                            .foregroundStyle(Color.pfTextSecondary)
                            .accessibilityLabel("\(interested) applications")
                    }
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func color(for status: ListingStatus) -> Color {
        switch status {
        case .available: Color.pfSuccess
        case .pending: Color.pfBrandPrimary
        case .adopted: Color.pfTextSecondary
        }
    }

    @ViewBuilder
    private func statusMenu(for pet: Pet) -> some View {
        let current = ListingStatus(petStatus: pet.status)
        ForEach(ListingStatus.allCases.filter { $0 != current }, id: \.self) { status in
            Button("Mark as \(status.title.lowercased())") { setStatus(status, for: pet) }
        }
        Button("Delete", systemImage: "trash", role: .destructive) { petToDelete = pet }
    }

    private func setStatus(_ status: ListingStatus, for pet: Pet) {
        Task {
            do {
                try await listings.setStatus(status, for: pet.id)
            } catch {
                errorMessage = backendError(error).localizedDescription
            }
        }
    }

    private func delete(_ pet: Pet) {
        Task {
            do {
                try await listings.delete(listingID: pet.id, photoCount: pet.photoURLs.count)
            } catch {
                errorMessage = backendError(error).localizedDescription
            }
        }
    }
}
