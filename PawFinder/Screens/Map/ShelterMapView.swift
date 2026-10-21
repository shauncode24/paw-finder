import MapKit
import SwiftUI

/// The Map tab: shelters near you, grouped into clusters when zoomed out.
/// Tap a pin for a summary card; "Search this area" after moving the map.
/// Also has a list view (easier with VoiceOver).
/// Third iteration
struct ShelterMapView: View {
    @State private var viewModel: ShelterMapViewModel
    @State private var position: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedShelterID: String?
    @State private var showSearchArea = false
    @State private var placeText = ""
    @State private var showsList = false
    @State private var locationError: String?

    @Environment(LocationService.self) private var locationService
    @Environment(FollowedSheltersStore.self) private var followed

    init(repository: PetRepository) {
        _viewModel = State(initialValue: ShelterMapViewModel(repository: repository))
    }

    private var visible: [Shelter] { viewModel.visibleShelters(followed: followed) }
    private var selectedShelter: Shelter? { visible.first { $0.id == selectedShelterID } }

    var body: some View {
        Group {
            if showsList {
                shelterList
            } else {
                map
            }
        }
        .safeAreaInset(edge: .top) { topBar }
        .safeAreaInset(edge: .bottom) { bottomPanel }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { showsList.toggle() }
                } label: {
                    Image(systemName: showsList ? "map" : "list.bullet")
                }
                .accessibilityLabel(showsList ? "Show map" : "Show list")
            }
        }
        .task {
            // Start near the user if they've already allowed location.
            if case .needsLocation = viewModel.state, hasLocationPermission {
                await searchNearMe()
            }
        }
    }

    private var hasLocationPermission: Bool {
        let status = locationService.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    // MARK: - Map

    /// Pins and clusters for the current zoom level.
    private var clusters: [ShelterCluster] {
        ShelterCluster.make(from: visible, coordinates: viewModel.coordinates, region: visibleRegion)
    }

    private var map: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(clusters) { cluster in
                Annotation(cluster.annotationTitle, coordinate: cluster.coordinate) {
                    annotationContent(for: cluster)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: MapCameraUpdateFrequency.onEnd) { context in
            mapCameraMoved(to: context.region)
        }
    }

    /// One shelter shows as a pin; several close together show as a numbered bubble.
    @ViewBuilder
    private func annotationContent(for cluster: ShelterCluster) -> some View {
        if let shelter = cluster.singleShelter {
            ShelterPin(isSelected: shelter.id == selectedShelterID,
                       isFollowed: followed.isFollowing(shelter.id))
                .onTapGesture { select(shelter) }
                .accessibilityLabel(shelter.name)
                .accessibilityAddTraits(.isButton)
        } else {
            ClusterBubble(count: cluster.shelters.count)
                .onTapGesture { zoom(into: cluster) }
                .accessibilityLabel("\(cluster.shelters.count) shelters. Double tap to zoom in.")
                .accessibilityAddTraits(.isButton)
        }
    }

    private func select(_ shelter: Shelter) {
        withAnimation { selectedShelterID = shelter.id }
    }

    /// Remembers the visible area, and offers "Search this area" once the
    /// map has moved well away from where the last search was centred.
    private func mapCameraMoved(to region: MKCoordinateRegion) {
        visibleRegion = region
        guard let center = viewModel.searchCenter else { return }
        let searched = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let current = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let milesMoved: Double = searched.distance(from: current) / 1609.34
        let threshold: Double = region.radiusMiles * 0.4
        showSearchArea = milesMoved > threshold
    }

    private func zoom(into cluster: ShelterCluster) {
        let span = visibleRegion?.span ?? MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: cluster.coordinate,
                span: MKCoordinateSpan(latitudeDelta: span.latitudeDelta / 3, longitudeDelta: span.longitudeDelta / 3)
            ))
        }
    }

    // MARK: - List

    private var shelterList: some View {
        List {
            ForEach(visible) { shelter in
                NavigationLink(value: Route.shelter(id: shelter.id)) {
                    ShelterRow(shelter: shelter, miles: miles(to: shelter),
                               isFollowed: followed.isFollowing(shelter.id))
                }
                .listRowBackground(Color.pfSurface)
            }
            if viewModel.hasMore {
                Button("Load more shelters") { Task { await viewModel.loadMore() } }
                    .listRowBackground(Color.pfSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pfBackground)
        .overlay {
            if case .loaded = viewModel.state, visible.isEmpty {
                EmptyStateView(icon: "house", title: "No shelters", message: "Try a bigger distance or fewer filters.")
            }
        }
    }

    // MARK: - Top bar: place search + chips

    private var topBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.pfTextSecondary)
                TextField("ZIP code or City, ST", text: $placeText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await searchPlace() } }
                Button {
                    Task { await searchNearMe() }
                } label: {
                    Image(systemName: "location.fill")
                }
                .accessibilityLabel("Use my location")
            }
            .padding(Spacing.md)
            .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
            .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(ShelterMapViewModel.distanceOptions, id: \.self) { miles in
                        PFChip(title: "\(miles) mi", isSelected: viewModel.distance == miles) {
                            viewModel.distance = miles
                            Task { await researchCurrentPlace() }
                        }
                    }
                    PFChip(title: "Open now", isSelected: viewModel.openNowOnly) {
                        viewModel.openNowOnly.toggle()
                    }
                    PFChip(title: "Following", isSelected: viewModel.followingOnly) {
                        viewModel.followingOnly.toggle()
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(.bar)
    }

    // MARK: - Bottom panel: status, selected shelter, or "Search this area"

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(spacing: Spacing.sm) {
            if let locationError {
                messageCard(locationError, icon: "location.slash")
            }

            switch viewModel.state {
            case .needsLocation:
                startCard
            case .loading:
                messageCard("Finding shelters...", icon: nil, showsProgress: true)
            case .error(let message):
                messageCard(message, icon: "exclamationmark.triangle")
            case .loaded:
                if !showsList {
                    loadedPanel
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }

    /// The selected shelter's card, the "Search this area" button, or a summary.
    @ViewBuilder
    private var loadedPanel: some View {
        if let shelter = selectedShelter {
            SelectedShelterCard(shelter: shelter,
                                coordinate: viewModel.coordinates[shelter.id],
                                miles: miles(to: shelter),
                                close: { withAnimation { selectedShelterID = nil } })
        } else if showSearchArea {
            PFButton(title: "Search this area") { Task { await searchVisibleArea() } }
                .frame(maxWidth: 220)
        } else {
            Text(summaryText)
                .font(.pfCaption)
                .foregroundStyle(Color.pfTextSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(.regularMaterial, in: Capsule())
        }
    }

    private var summaryText: String {
        let count: Int = visible.count
        let noun: String = count == 1 ? "shelter" : "shelters"
        var text: String = "\(count) \(noun)"
        if viewModel.isGeocoding { text += " · placing pins..." }
        if count < viewModel.shelters.count { text += " (filtered)" }
        return text
    }

    private var startCard: some View {
        PFCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Find shelters near you")
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                Text(locationService.isDenied
                     ? "Location is off. Type a ZIP code or city above."
                     : "Use your location, or type a ZIP code or city above.")
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
                if !locationService.isDenied {
                    PFButton(title: "Use my location") { Task { await searchNearMe() } }
                }
            }
        }
    }

    private func messageCard(_ text: String, icon: String?, showsProgress: Bool = false) -> some View {
        HStack(spacing: Spacing.sm) {
            if showsProgress { ProgressView() }
            if let icon { Image(systemName: icon) }
            Text(text).font(.subheadline)
        }
        .foregroundStyle(Color.pfTextPrimary)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.medium))
    }

    // MARK: - Searching

    private func searchNearMe() async {
        locationError = nil
        do {
            let location = try await locationService.requestLocation()
            await search(location: location.petfinderQuery, center: location.coordinate)
        } catch {
            locationError = error.localizedDescription
        }
    }

    private func searchPlace() async {
        let place = placeText.trimmingCharacters(in: .whitespaces)
        guard !place.isEmpty else { return }
        locationError = nil
        let center = await ShelterGeocoder.shared.coordinate(forAddress: place)
        await search(location: place, center: center)
    }

    private func searchVisibleArea() async {
        guard let region = visibleRegion else { return }
        let center = region.center
        let miles = min(max(Int(region.radiusMiles.rounded()), 5), 500)
        showSearchArea = false
        selectedShelterID = nil
        // Keep the camera where the user put it.
        await viewModel.search(location: "\(center.latitude),\(center.longitude)", center: center, distance: miles)
    }

    /// Re-runs the last search with the new distance chip.
    private func researchCurrentPlace() async {
        guard let center = viewModel.searchCenter else { return }
        await search(location: "\(center.latitude),\(center.longitude)", center: center)
    }

    private func search(location: String, center: CLLocationCoordinate2D?) async {
        selectedShelterID = nil
        showSearchArea = false
        if let center {
            withAnimation {
                position = .region(MKCoordinateRegion(center: center, radiusMiles: Double(viewModel.distance)))
            }
        }
        await viewModel.search(location: location, center: center)
        // Fit the camera to the pins (and the user) once they're placed.
        withAnimation { position = .automatic }
    }

    private func miles(to shelter: Shelter) -> Double? {
        if let user = locationService.lastLocation, let coordinate = viewModel.coordinates[shelter.id] {
            return user.miles(to: coordinate)
        }
        return shelter.distance
    }
}

// MARK: - Pieces

/// "Austin, TX · 12 mi away". Leaves out whichever part is missing.
private func shelterDetailLine(cityState: String, miles: Double?, suffix: String) -> String {
    var parts: [String] = []
    if !cityState.isEmpty {
        parts.append(cityState)
    }
    if let miles {
        let rounded: Int = Int(miles.rounded())
        parts.append("\(rounded) mi\(suffix)")
    }
    return parts.joined(separator: " · ")
}

private extension ShelterCluster {
    /// The shelter, when this is a lone pin rather than a group.
    var singleShelter: Shelter? {
        shelters.count == 1 ? shelters.first : nil
    }

    /// Pins show their name; group bubbles have none.
    var annotationTitle: String {
        singleShelter?.name ?? ""
    }
}

private struct ShelterPin: View {
    let isSelected: Bool
    let isFollowed: Bool

    var body: some View {
        Image(systemName: isFollowed ? "star.fill" : "house.fill")
            .font(.system(size: isSelected ? 18 : 14, weight: .semibold))
            .foregroundStyle(Color.pfSurfaceElevated)
            .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
            .background(isSelected ? Color.pfBrandPrimary : Color.pfBrandLight, in: Circle())
            .overlay(Circle().stroke(Color.pfSurfaceElevated, lineWidth: 2))
            .shadow(radius: 2)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }
}

private struct ClusterBubble: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.pfSurfaceElevated)
            .frame(width: 44, height: 44)
            .background(Color.pfBrandPrimary, in: Circle())
            .overlay(Circle().stroke(Color.pfSurfaceElevated, lineWidth: 3))
            .shadow(radius: 2)
    }
}

private struct ShelterRow: View {
    let shelter: Shelter
    let miles: Double?
    let isFollowed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(shelter.name)
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                if isFollowed {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.pfBrandPrimary)
                        .accessibilityLabel("Following")
                }
            }
            Text(shelterDetailLine(cityState: shelter.cityState, miles: miles, suffix: ""))
                .font(.subheadline)
                .foregroundStyle(Color.pfTextSecondary)
            OpenStatusLabel(shelter: shelter)
        }
        .padding(.vertical, Spacing.xs)
    }
}

/// The card that slides up when a pin is tapped.
private struct SelectedShelterCard: View {
    let shelter: Shelter
    let coordinate: CLLocationCoordinate2D?
    let miles: Double?
    let close: () -> Void

    var body: some View {
        PFCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(shelter.name)
                            .font(.pfHeadline)
                            .foregroundStyle(Color.pfTextPrimary)
                        Text(shelterDetailLine(cityState: shelter.cityState, miles: miles, suffix: " away"))
                            .font(.subheadline)
                            .foregroundStyle(Color.pfTextSecondary)
                        OpenStatusLabel(shelter: shelter)
                    }
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                    .accessibilityLabel("Close")
                }
                HStack(spacing: Spacing.sm) {
                    NavigationLink(value: Route.shelter(id: shelter.id)) {
                        Text("View shelter")
                            .font(.pfHeadline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(Color.pfSurfaceElevated)
                            .background(Color.pfBrandPrimary, in: RoundedRectangle(cornerRadius: Radius.medium))
                    }
                    if let coordinate {
                        Link(destination: MapsLink.directions(name: shelter.name, coordinate: coordinate)) {
                            Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(Color.pfBrandPrimary)
                                .background(Color.pfBrandDeep, in: RoundedRectangle(cornerRadius: Radius.medium))
                        }
                    }
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    NavigationStack {
        ShelterMapView(repository: MockPetRepository())
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
    }
    .environment(LocationService())
    .environment(FollowedSheltersStore())
}
