import SwiftUI

/// Everything about one pet: photos, details, shelter, and similar pets.
struct PetDetailView: View {
    @State private var viewModel: PetDetailViewModel
    @State private var isDescriptionExpanded = false
    @State private var showReport = false
    @Environment(RecentlyViewedStore.self) private var recentlyViewed

    private var pet: Pet { viewModel.pet }

    init(pet: Pet, repository: PetRepository) {
        _viewModel = State(initialValue: PetDetailViewModel(pet: pet, repository: repository))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PhotoCarousel(photoURLs: photos, species: pet.species)

                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header
                    attributeChips
                    about
                    goodWith
                    section("Shelter") {
                        ShelterCard(state: viewModel.shelterState,
                                    coordinate: viewModel.shelterCoordinate,
                                    pet: pet) {
                            Task { await viewModel.loadShelter() }
                        }
                    }
                    if !viewModel.similarPets.isEmpty {
                        PetRail(title: "Similar pets", pets: viewModel.similarPets)
                    }
                }
                .padding(Spacing.lg)
            }
        }
        .background(Color.pfBackground)
        .navigationTitle(pet.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                shareButton
                Menu {
                    Button("Report listing", systemImage: "flag") { showReport = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $showReport) {
            ReportListingSheet(pet: pet)
        }
        .task { await viewModel.load() }
        .onAppear { recentlyViewed.add(pet) }
    }

    // MARK: - Sections

    private var photos: [URL] {
        pet.photoURLs.isEmpty ? [pet.thumbnailURL].compactMap { $0 } : pet.photoURLs
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(pet.name)
                .font(.largeTitle.bold())
                .foregroundStyle(Color.pfTextPrimary)
            Text(pet.breed)
                .font(.pfHeadline)
                .foregroundStyle(Color.pfTextSecondary)
            if !pet.location.isEmpty {
                Label(locationText, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
            }
        }
    }

    private var locationText: String {
        if let distance = pet.distance {
            return "\(pet.location) · \(Int(distance.rounded())) mi away"
        }
        return pet.location
    }

    private var attributeChips: some View {
        FlowLayout {
            ForEach([pet.age, pet.gender, pet.size].filter { !$0.isEmpty }, id: \.self) { value in
                PFChip(title: value, isSelected: true)
            }
            ForEach(pet.tags, id: \.self) { tag in
                PFChip(title: tag)
            }
        }
    }

    @ViewBuilder
    private var about: some View {
        section("About \(pet.name)") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let description = pet.description, !description.isEmpty {
                    Text(description)
                        .font(.pfBody)
                        .foregroundStyle(Color.pfTextPrimary)
                        .lineLimit(isDescriptionExpanded ? nil : 4)
                    if description.count > 180 {
                        Button(isDescriptionExpanded ? "Show less" : "Read more") {
                            withAnimation { isDescriptionExpanded.toggle() }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                } else {
                    Text("The shelter hasn't added a description yet.")
                        .foregroundStyle(Color.pfTextSecondary)
                }
                // Petfinder only sends a short preview of the description.
                if let webURL = pet.webURL {
                    Link("View full listing on Petfinder", destination: webURL)
                        .font(.subheadline)
                }
            }
        }
    }

    private var goodWith: some View {
        section("Good to know") {
            PFCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    yesNoRow("Good with kids", pet.goodWithKids)
                    yesNoRow("Good with dogs", pet.goodWithDogs)
                    yesNoRow("Good with cats", pet.goodWithCats)
                    yesNoRow("House-trained", pet.houseTrained)
                    if pet.specialNeeds {
                        Label("Has special needs. Ask the shelter for details.", systemImage: "heart.text.square")
                            .foregroundStyle(Color.pfTextPrimary)
                    }
                }
            }
        }
    }

    /// true = check, false = cross, nil = "Unknown".
    private func yesNoRow(_ title: String, _ value: Bool?) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.pfTextPrimary)
            Spacer()
            switch value {
            case true?:
                Label("Yes", systemImage: "checkmark.circle.fill").foregroundStyle(Color.pfSuccess)
            case false?:
                Label("No", systemImage: "xmark.circle.fill").foregroundStyle(Color.pfError)
            case nil:
                Text("Unknown").foregroundStyle(Color.pfTextSecondary)
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var shareButton: some View {
        let message = "Meet \(pet.name), a \(pet.breed) up for adoption!"
        if let webURL = pet.webURL {
            ShareLink(item: webURL, subject: Text(pet.name), message: Text(message))
        } else {
            ShareLink(item: message)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.pfTitle)
                .foregroundStyle(Color.pfTextPrimary)
            content()
        }
    }
}

#Preview {
    NavigationStack {
        PetDetailView(pet: MockPetRepository.samplePets[0], repository: MockPetRepository())
    }
    .environment(RecentlyViewedStore())
}
