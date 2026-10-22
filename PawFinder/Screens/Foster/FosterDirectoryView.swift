import MapKit
import SwiftUI

/// Profile › Foster volunteers nearby (listers only): a list and a map of
/// volunteers who are available, nearest first. "Invite to foster" opens a chat
/// about one of your pets that needs a foster.
struct FosterDirectoryView: View {
    @Environment(FosterStore.self) private var fosters
    @Environment(ListingsService.self) private var listings
    @Environment(ListerProfileStore.self) private var listerStore
    @Environment(LocationService.self) private var locationService
    @Environment(MessagesStore.self) private var messages
    @Environment(AuthManager.self) private var auth
    @Environment(Router.self) private var router

    @State private var directory: [FosterProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var center: CLLocationCoordinate2D?
    @State private var radius = 50
    @State private var species: PetFilters.Species?
    @State private var showsMap = false
    @State private var selectedID: String?
    @State private var position: MapCameraPosition = .automatic
    @State private var inviting: FosterProfile?
    @State private var noListingAlert = false
    @State private var actionError: String?

    private static let radiusOptions = [25, 50, 100, 0]   // 0 = any distance

    private var needingFoster: [Pet] { listings.myListings.filter(\.needsFoster) }

    /// Volunteers matching the chips, nearest first.
    private var visible: [FosterProfile] {
        let filtered: [FosterProfile] = directory.filter { foster in
            if let species, !foster.species.contains(species) { return false }
            if let center, radius > 0, let miles = miles(from: center, to: foster) { return miles <= Double(radius) }
            return true
        }
        guard let center else { return filtered }
        return filtered.sorted { (miles(from: center, to: $0) ?? .infinity) < (miles(from: center, to: $1) ?? .infinity) }
    }

    var body: some View {
        Group {
            if listerStore.isLoaded, !listerStore.isLister {
                EmptyStateView(icon: "house.and.flag", title: "For listers",
                               message: "The foster directory is for people who list pets. Set up a lister profile to see volunteers near you.",
                               buttonTitle: "Set up lister profile") { router.push(.listerSetup) }
            } else if isLoading {
                LoadingView(message: "Finding volunteers...")
            } else if let errorMessage {
                ErrorView(message: errorMessage) { Task { await load() } }
            } else {
                content
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("Foster volunteers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { showsMap.toggle() }
                } label: {
                    Image(systemName: showsMap ? "list.bullet" : "map")
                }
                .accessibilityLabel(showsMap ? "Show list" : "Show map")
            }
        }
        .task(id: listerStore.isLister) { await load() }
        .sheet(item: $inviting) { foster in invitePicker(foster) }
        .alert("No pet needs a foster yet", isPresented: $noListingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Edit one of your listings and switch on \"This pet needs a foster\", then invite a volunteer.")
        }
        .alert("Couldn't open the chat", isPresented: Binding(get: { actionError != nil },
                                                             set: { if !$0 { actionError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            chips
            if showsMap {
                map
            } else if visible.isEmpty {
                EmptyStateView(icon: "house.and.flag", title: "No volunteers found",
                               message: directory.isEmpty
                                   ? "Nobody has signed up to foster yet."
                                   : "Try a bigger distance or a different kind of animal.")
            } else {
                list
            }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(Self.radiusOptions, id: \.self) { miles in
                    PFChip(title: miles == 0 ? "Any distance" : DistanceUnit.current.label(miles: miles), isSelected: radius == miles) {
                        radius = miles
                    }
                }
                ForEach(PetFilters.Species.allCases, id: \.self) { option in
                    PFChip(title: option.rawValue, isSelected: species == option) {
                        species = species == option ? nil : option
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
        }
        .background(.bar)
    }

    private var list: some View {
        List {
            ForEach(visible, id: \.uid) { foster in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    card(foster)
                    Button {
                        invite(foster)
                    } label: {
                        Label("Invite to foster", systemImage: "paperplane")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.pfBrandPrimary)
                }
                .padding(.vertical, Spacing.xs)
                .listRowBackground(Color.pfSurface)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var map: some View {
        Map(position: $position, selection: $selectedID) {
            UserAnnotation()
            ForEach(visible, id: \.uid) { foster in
                if let latitude = foster.latitude, let longitude = foster.longitude {
                    Marker(foster.publicName, systemImage: "house.fill",
                           coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                        .tint(Color.pfBrandPrimary)
                        .tag(foster.uid)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .safeAreaInset(edge: .bottom) {
            if let foster = visible.first(where: { $0.uid == selectedID }) {
                PFCard {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        card(foster)
                        PFButton(title: "Invite to foster") { invite(foster) }
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }

    /// One volunteer's details: name, where, what they can take.
    private func card(_ foster: FosterProfile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(foster.publicName)
                .font(.pfHeadline)
                .foregroundStyle(Color.pfTextPrimary)
            Text(placeLine(foster))
                .font(.subheadline)
                .foregroundStyle(Color.pfTextSecondary)
            Text(foster.summary)
                .font(.pfCaption)
                .foregroundStyle(Color.pfTextPrimary)
            Text(detailLine(foster))
                .font(.pfCaption)
                .foregroundStyle(Color.pfTextSecondary)
            if !foster.bio.isEmpty {
                Text(foster.bio)
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
                    .lineLimit(3)
            }
        }
    }

    private func placeLine(_ foster: FosterProfile) -> String {
        var parts: [String] = []
        if !foster.cityState.isEmpty { parts.append(foster.cityState) }
        if let center, let miles = miles(from: center, to: foster) { parts.append(DistanceUnit.current.away(miles: miles)) }
        return parts.joined(separator: " · ")
    }

    private func detailLine(_ foster: FosterProfile) -> String {
        var parts: [String] = [foster.duration.rawValue]
        if let experience = foster.experience { parts.append(experience.rawValue) }
        if let home = foster.homeType { parts.append(home.rawValue) }
        if foster.hasOtherPets { parts.append("has other pets") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Inviting

    private func invite(_ foster: FosterProfile) {
        switch needingFoster.count {
        case 0: noListingAlert = true
        case 1: openChat(with: foster, about: needingFoster[0])
        default: inviting = foster
        }
    }

    private func invitePicker(_ foster: FosterProfile) -> some View {
        NavigationStack {
            List(needingFoster) { pet in
                Button {
                    inviting = nil
                    openChat(with: foster, about: pet)
                } label: {
                    HStack(spacing: Spacing.md) {
                        Color.clear
                            .frame(width: 48, height: 48)
                            .overlay { PetPhoto(url: pet.thumbnailURL, species: pet.species) }
                            .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pet.name).font(.pfHeadline).foregroundStyle(Color.pfTextPrimary)
                            Text(pet.fosterReason ?? pet.breed).font(.pfCaption).foregroundStyle(Color.pfTextSecondary)
                        }
                    }
                }
                .listRowBackground(Color.pfSurface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.pfBackground)
            .navigationTitle("Invite \(foster.publicName) for…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { inviting = nil } }
            }
        }
        .presentationDetents([.medium])
    }

    /// Starts a chat about the pet, with the volunteer in the "other person" role.
    private func openChat(with foster: FosterProfile, about pet: Pet) {
        guard let me = auth.user else { return }
        Task {
            do {
                let id = try await messages.openConversation(
                    listingID: pet.id, listingName: pet.name, listingSpecies: pet.species,
                    adopterID: foster.uid, adopterName: foster.publicName,
                    listerID: me.id, listerName: listerStore.profile?.publicName ?? "Lister")
                router.push(.conversation(id))
            } catch {
                actionError = error.localizedDescription
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard listerStore.isLister else { return }

        if let profile = listerStore.profile, let latitude = profile.latitude, let longitude = profile.longitude {
            center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        if let location = locationService.lastLocation { center = location.coordinate }
        do {
            directory = try await fosters.loadDirectory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func miles(from center: CLLocationCoordinate2D, to foster: FosterProfile) -> Double? {
        guard let latitude = foster.latitude, let longitude = foster.longitude else { return nil }
        return CLLocation(latitude: center.latitude, longitude: center.longitude)
            .miles(to: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
    }
}

extension FosterProfile: Identifiable {
    var id: String { uid }
}
