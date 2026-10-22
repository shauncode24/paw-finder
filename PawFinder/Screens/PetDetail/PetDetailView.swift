import SwiftUI

/// Everything about one pet: photos, details, who's listing them, and similar pets.
struct PetDetailView: View {
    @State private var viewModel: PetDetailViewModel
    @State private var isDescriptionExpanded = false
    @State private var showReport = false
    @State private var isOpeningChat = false
    @State private var chatError: String?
    @Environment(RecentlyViewedStore.self) private var recentlyViewed
    @Environment(FavoritesStore.self) private var favorites
    @Environment(LocationService.self) private var locationService
    @Environment(ApplicationsStore.self) private var applications
    @Environment(ProfileStore.self) private var profileStore
    @Environment(AuthManager.self) private var auth
    @Environment(Router.self) private var router
    @Environment(MessagesStore.self) private var messages
    @Environment(FosterStore.self) private var fosters
    @State private var showFosterOffer = false

    private var pet: Pet { viewModel.pet }

    /// True when the signed-in user is the one who listed this pet.
    private var isMine: Bool { auth.user?.id == pet.shelterID }

    /// The lister's name, once their profile has loaded.
    private var listerName: String? {
        if case .loaded(let shelter) = viewModel.shelterState { return shelter.name }
        return pet.listedBy
    }

    init(pet: Pet, repository: PetRepository) {
        _viewModel = State(initialValue: PetDetailViewModel(pet: pet, repository: repository))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PhotoCarousel(photoURLs: photos, species: pet.species)

                VStack(alignment: .leading, spacing: Spacing.xl) {
                    statusBanner
                    fosterBanner
                    header
                    if isMine {
                        ownerControls
                    } else {
                        applyButton
                        PFButton(title: "Message \(listerName ?? "the lister")", style: .secondary,
                                 isLoading: isOpeningChat) { openChat() }
                        if pet.needsFoster { offerToFosterButton }
                    }
                    attributeChips
                    if favorites.isFavorite(pet.id) {
                        FavoriteNotesSection(pet: pet)
                    }
                    about
                    if let video = pet.videoLink {
                        Link(destination: video) {
                            Label("Watch \(pet.name)'s video", systemImage: "play.rectangle.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    goodWith
                    section("Listed by") {
                        ShelterCard(state: viewModel.shelterState,
                                    coordinate: viewModel.shelterCoordinate,
                                    userLocation: locationService.lastLocation,
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
                FavoriteButton(pet: pet)
                shareButton
                Menu {
                    if isMine {
                        Button("Edit listing", systemImage: "pencil") { router.push(.editListing(pet.id)) }
                    } else {
                        Button("Report listing", systemImage: "flag") { showReport = true }
                    }
                    if !viewModel.similarPets.isEmpty {
                        Button("Compare with similar pets", systemImage: "rectangle.on.rectangle") {
                            router.push(.compare([pet] + Array(viewModel.similarPets.prefix(2))))
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $showReport) {
            ReportListingSheet(pet: pet)
        }
        .sheet(isPresented: $showFosterOffer) {
            FosterOfferSheet(pet: pet, listerName: listerName)
        }
        .task { await viewModel.load() }
        .alert("Couldn't open the chat", isPresented: Binding(get: { chatError != nil },
                                                             set: { if !$0 { chatError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(chatError ?? "")
        }
        // Handoff: pick up this pet on another device signed in to the same Apple ID.
        .userActivity("com.pawfinder.viewPet") { activity in
            activity.title = "\(pet.name) on PawFinder"
            activity.userInfo = ["petID": pet.id]
            activity.webpageURL = pet.webURL
            activity.isEligibleForHandoff = true
        }
        // Keep the saved favorite up to date with the fresh copy.
        .onChange(of: viewModel.pet) { _, fresh in
            favorites.updateSnapshot(fresh)
        }
        .onAppear {
            recentlyViewed.add(pet)
            favorites.markStatusSeen(pet.id)
        }
    }

    // MARK: - Sections

    /// "Apply to adopt", or the status of an application already started.
    @ViewBuilder
    private var applyButton: some View {
        if let existing = applications.openApplication(for: pet.id) {
            Button {
                router.push(existing.status == .draft ? .applicationForm(existing.id) : .applicationDetail(existing.id))
            } label: {
                HStack {
                    StatusBadge(status: existing.status)
                    Text(existing.status == .draft ? "Continue your application" : "View your application")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.pfBrandPrimary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Color.pfTextSecondary)
                }
                .padding(Spacing.md)
                .background(Color.pfSurface, in: RoundedRectangle(cornerRadius: Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))
            }
            .buttonStyle(.plain)
        } else if !pet.isAdopted {
            PFButton(title: "Apply to adopt \(pet.name)") {
                // Applications go to a real person, so an account is needed.
                guard auth.user != nil else {
                    router.showSignIn = true
                    return
                }
                let id = applications.startOrResume(pet: pet, shelterName: listerName,
                                                    profile: profileStore.profile, email: auth.user?.email)
                router.push(.applicationForm(id))
            }
        }
    }

    /// Shown instead of Apply/Message when you're looking at your own listing.
    private var ownerControls: some View {
        PFCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("This is your listing", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                Text("This is how adopters see \(pet.name). Update the details, photos, or status any time.")
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
                PFButton(title: "Edit listing") { router.push(.editListing(pet.id)) }
                PFButton(title: "Applications received", style: .secondary) { router.push(.receivedApplications) }
                if pet.needsFoster {
                    PFButton(title: "Find foster volunteers", style: .secondary) { router.push(.fosterDirectory) }
                }
            }
        }
    }

    private func openChat() {
        guard let me = auth.user else {
            router.showSignIn = true
            return
        }
        isOpeningChat = true
        let myName = profileStore.profile.displayName.isEmpty ? (me.displayName ?? "") : profileStore.profile.displayName
        Task {
            defer { isOpeningChat = false }
            do {
                let id = try await messages.openChat(about: pet, listerName: listerName, as: me, displayName: myName)
                router.push(.conversation(id))
            } catch {
                chatError = error.localizedDescription
            }
        }
    }

    /// Shown when a saved pet was adopted or removed, or has an adoption pending.
    @ViewBuilder
    private var statusBanner: some View {
        let favorite = favorites.favorite(for: pet.id)
        if favorite?.isListed == false {
            banner("This listing was removed by the lister. The pet may have been adopted.", color: .pfError)
        } else if (favorite?.pet ?? pet).isAdopted {
            banner("\(pet.name) has been adopted!", color: .pfSuccess)
        } else if pet.isPending {
            banner("Adoption pending: an application has been approved. Ask the lister if they're still looking.", color: .pfBrandPrimary)
        }
    }

    /// "Needs a foster" (with the reason) or "In foster care with…".
    @ViewBuilder
    private var fosterBanner: some View {
        if pet.isInFosterCare {
            banner("In foster care with \(pet.fosterByName ?? "a volunteer"). Ask the lister to arrange a meeting.",
                   color: .pfBrandPrimary)
        } else if pet.needsFoster {
            let detail: String = [pet.fosterReason, pet.fosterDuration].compactMap { $0 }.joined(separator: " · ")
            banner(detail.isEmpty ? "\(pet.name) needs a foster home." : "\(pet.name) needs a foster home. \(detail)",
                   color: .pfBrandPrimary)
        }
    }

    /// Volunteers offer to foster; this asks for a foster profile first.
    private var offerToFosterButton: some View {
        PFButton(title: fosters.offer(forListing: pet.id) == nil ? "Offer to foster \(pet.name)" : "View your foster offer",
                 style: .secondary) {
            guard auth.user != nil else {
                router.showSignIn = true
                return
            }
            if fosters.offer(forListing: pet.id) != nil {
                router.push(.fosterOffers)
            } else if fosters.isFoster {
                showFosterOffer = true
            } else {
                router.push(.fosterProfile)
            }
        }
    }

    private func banner(_ text: String, color: Color) -> some View {
        Label(text, systemImage: "info.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.medium))
    }

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
            return "\(pet.location) · \(DistanceUnit.current.away(miles: distance))"
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
                    Text("The lister hasn't added a description yet.")
                        .foregroundStyle(Color.pfTextSecondary)
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
                    yesNoRow("Vaccinated", pet.vaccinated)
                    yesNoRow("Spayed or neutered", pet.spayedNeutered)
                    yesNoRow("Microchipped", pet.microchipped)
                    factRow("Adoption fee", pet.feeText)
                    factRow("Exact age", pet.ageDetail)
                    factRow("Colors", pet.colors)
                    factRow("Coat", pet.coat)
                    factRow("Weight", pet.weight)
                    if pet.specialNeeds {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Label("Has special needs", systemImage: "heart.text.square")
                                .foregroundStyle(Color.pfTextPrimary)
                            if let notes = pet.specialNeedsNotes {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.pfTextSecondary)
                            }
                        }
                    }
                    if let health = pet.healthNotes {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Health notes").font(.subheadline.weight(.semibold))
                            Text(health)
                                .font(.subheadline)
                                .foregroundStyle(Color.pfTextSecondary)
                        }
                    }
                }
            }
        }
    }

    /// A label and a value, left out when there's no value.
    @ViewBuilder
    private func factRow(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack {
                Text(title).foregroundStyle(Color.pfTextPrimary)
                Spacer()
                Text(value).foregroundStyle(Color.pfTextSecondary)
            }
            .font(.subheadline)
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
    .environment(FavoritesStore(fileName: "preview-favorites.json"))
    .environment(LocationService())
    .environment(FollowedSheltersStore())
    .environment(AuthManager())
    .environment(ProfileStore())
    .environment(ApplicationsStore())
    .environment(Router())
    .environment(MessagesStore())
    .environment(FosterStore())
    .environment(ListingsService())
}
