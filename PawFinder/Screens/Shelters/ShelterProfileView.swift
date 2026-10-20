import SwiftUI

/// A shelter's page: photo, open-now, follow, contact, map, hours, about,
/// adoption policy, and the pets it currently has.
struct ShelterProfileView: View {
    @State private var viewModel: ShelterProfileViewModel
    @State private var isAboutExpanded = false
    @Environment(FollowedSheltersStore.self) private var followed
    @Environment(LocationService.self) private var locationService
    @Environment(MessagesStore.self) private var messages
    @Environment(Router.self) private var router

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: Spacing.md)]

    init(shelterID: String, repository: PetRepository) {
        _viewModel = State(initialValue: ShelterProfileViewModel(shelterID: shelterID, repository: repository))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Loading shelter...")
            case .error(let message):
                ErrorView(message: message) { Task { await viewModel.load() } }
            case .loaded(let shelter):
                content(shelter)
            }
        }
        .background(Color.pfBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private func content(_ shelter: Shelter) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(shelter)

                VStack(alignment: .leading, spacing: Spacing.xl) {
                    titleBlock(shelter)
                    followButton(shelter)
                    PFButton(title: "Message \(shelter.name)", style: .secondary) {
                        let id = messages.startConversation(shelterID: shelter.id, shelterName: shelter.name, pet: nil)
                        router.push(.conversation(id))
                    }
                    ContactButtons(phone: shelter.phone, email: shelter.email,
                                   website: shelter.website ?? shelter.petfinderURL)

                    if let coordinate = viewModel.coordinate {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ShelterMiniMap(name: shelter.name, coordinate: coordinate)
                            Link(destination: MapsLink.directions(name: shelter.name, coordinate: coordinate)) {
                                Label("Get directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }

                    if !shelter.hours.isEmpty {
                        section("Hours") { hoursTable(shelter) }
                    }

                    if let mission = shelter.missionStatement, !mission.isEmpty {
                        section("About") {
                            Text(mission)
                                .foregroundStyle(Color.pfTextPrimary)
                                .lineLimit(isAboutExpanded ? nil : 5)
                            if mission.count > 220 {
                                Button(isAboutExpanded ? "Show less" : "Read more") {
                                    withAnimation { isAboutExpanded.toggle() }
                                }
                                .font(.subheadline.weight(.semibold))
                            }
                        }
                    }

                    if shelter.adoptionPolicy != nil || shelter.adoptionURL != nil {
                        section("Adoption policy") {
                            if let policy = shelter.adoptionPolicy {
                                Text(policy).foregroundStyle(Color.pfTextPrimary)
                            }
                            if let url = shelter.adoptionURL {
                                Link("Adoption info on their website", destination: url)
                                    .font(.subheadline)
                            }
                        }
                    }

                    section("Available pets") { petsGrid }
                }
                .padding(Spacing.lg)
            }
        }
        .navigationTitle(shelter.name)
        .toolbar {
            if let url = shelter.petfinderURL ?? shelter.website {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url, subject: Text(shelter.name))
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func header(_ shelter: Shelter) -> some View {
        Color.clear
            .frame(height: 200)
            .overlay {
                if let photo = shelter.photoURLs.first {
                    PetPhoto(url: photo)
                } else {
                    ZStack {
                        Color.pfBrandDeep
                        Image(systemName: "house.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.pfBrandLight)
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private func titleBlock(_ shelter: Shelter) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(shelter.name)
                .font(.largeTitle.bold())
                .foregroundStyle(Color.pfTextPrimary)
            if !shelter.address.isEmpty {
                Label(shelter.address, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
            }
            OpenStatusLabel(shelter: shelter)
            if let miles = distance(to: shelter) {
                Text("\(Int(miles.rounded())) miles away")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
            }
        }
    }

    private func followButton(_ shelter: Shelter) -> some View {
        let isFollowing = followed.isFollowing(shelter.id)
        return PFButton(title: isFollowing ? "Following ✓" : "Follow for new arrivals",
                        style: isFollowing ? .secondary : .primary) {
            followed.toggle(shelter)
            if followed.isFollowing(shelter.id) {
                Task { await NotificationManager.shared.requestAuthorizationIfNeeded() }
            }
        }
        .sensoryFeedback(.success, trigger: isFollowing)
    }

    /// Monday-first week, with today in bold.
    private func hoursTable(_ shelter: Shelter) -> some View {
        let today = Shelter.weekdayKey()
        let week = Array(Shelter.weekdays.dropFirst()) + [Shelter.weekdays[0]]
        return PFCard {
            VStack(spacing: Spacing.sm) {
                ForEach(week, id: \.self) { day in
                    HStack {
                        Text(day.capitalized)
                        Spacer()
                        Text(shelter.hours[day] ?? "Not listed")
                            .foregroundStyle(shelter.hours[day] == nil ? Color.pfTextSecondary : Color.pfTextPrimary)
                    }
                    .font(.subheadline.weight(day == today ? .bold : .regular))
                    .foregroundStyle(Color.pfTextPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private var petsGrid: some View {
        if viewModel.pets.isEmpty {
            if viewModel.isLoadingPets {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text("No adoptable pets listed right now.")
                    .foregroundStyle(Color.pfTextSecondary)
            }
        } else {
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(viewModel.pets) { pet in
                    NavigationLink(value: Route.petDetail(pet)) {
                        PetCard(pet: pet)
                    }
                    .buttonStyle(.plain)
                }
            }
            if viewModel.hasMorePets {
                PFButton(title: "Show more pets", style: .secondary, isLoading: viewModel.isLoadingPets) {
                    Task { await viewModel.loadMorePets() }
                }
            }
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

    private func distance(to shelter: Shelter) -> Double? {
        if let user = locationService.lastLocation, let coordinate = viewModel.coordinate {
            return user.miles(to: coordinate)
        }
        return shelter.distance
    }
}

#Preview {
    NavigationStack {
        ShelterProfileView(shelterID: "shelter-1", repository: MockPetRepository())
    }
    .environment(FollowedSheltersStore())
    .environment(LocationService())
    .environment(FavoritesStore(fileName: "preview-favorites.json"))
    .environment(MessagesStore())
    .environment(Router())
}
