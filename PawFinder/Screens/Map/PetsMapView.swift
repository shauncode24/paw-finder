import MapKit
import SwiftUI

/// The Map tab has two views: this one (one pin per pet, with its photo) and
/// the lister map (`ShelterMapView`).
struct MapHomeView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case pets = "Pets"
        case listers = "Listers"
        var id: String { rawValue }
    }

    let repository: PetRepository
    @AppStorage("mapMode") private var modeRaw = Mode.pets.rawValue

    private var mode: Mode { Mode(rawValue: modeRaw) ?? .pets }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Map shows", selection: $modeRaw) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)

            switch mode {
            case .pets: PetsMapView()
            case .listers: ShelterMapView(repository: repository)
            }
        }
    }
}

/// Every available pet on the map: its photo is the pin, pins close together
/// merge into numbered bubbles, and a circle shows the search distance.
/// Tap a pin for a card that opens the pet.
struct PetsMapView: View {
    @Environment(ListingsService.self) private var listings
    @Environment(LocationService.self) private var locationService
    @Environment(Router.self) private var router

    @State private var position: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var center: CLLocationCoordinate2D?
    @State private var radius = 25
    @State private var species: String?
    @State private var placeText = ""
    @State private var selectedID: String?
    @State private var stack: PetCluster?
    @State private var message: String?

    /// Miles; 0 means "any distance".
    private static let radiusOptions = [10, 25, 50, 100, 0]
    private static let speciesOptions = ["Dog", "Cat", "Rabbit", "Bird"]

    // MARK: - Data

    private var withLocation: [Pet] {
        listings.listings.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private func miles(from center: CLLocationCoordinate2D, to pet: Pet) -> Double? {
        guard let latitude = pet.latitude, let longitude = pet.longitude else { return nil }
        let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return origin.miles(to: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
    }

    /// Pets that pass the species chip and the distance circle.
    private var visiblePets: [Pet] {
        withLocation.filter { pet in
            if let species, pet.species != species { return false }
            if let center, radius > 0, let distance = miles(from: center, to: pet) {
                return distance <= Double(radius)
            }
            return true
        }
    }

    private var clusters: [PetCluster] {
        PetCluster.make(from: visiblePets, region: visibleRegion)
    }

    private var selectedPet: Pet? { visiblePets.first { $0.id == selectedID } }

    // MARK: - Body

    var body: some View {
        map
            .safeAreaInset(edge: .top) { topBar }
            .safeAreaInset(edge: .bottom) { bottomPanel }
            .sheet(item: $stack) { cluster in stackSheet(cluster) }
            .task {
                let status = locationService.authorizationStatus
                if center == nil, status == .authorizedWhenInUse || status == .authorizedAlways {
                    await useMyLocation()
                }
            }
    }

    private var map: some View {
        Map(position: $position) {
            UserAnnotation()
            if let center, radius > 0 {
                MapCircle(center: center, radius: Double(radius) * 1609.34)
                    .foregroundStyle(Color.pfBrandPrimary.opacity(0.1))
                    .stroke(Color.pfBrandPrimary, lineWidth: 2)
            }
            ForEach(clusters) { cluster in
                Annotation(cluster.single?.name ?? "", coordinate: cluster.coordinate) {
                    pin(for: cluster)
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
            visibleRegion = context.region
        }
    }

    @ViewBuilder
    private func pin(for cluster: PetCluster) -> some View {
        if let pet = cluster.single {
            PetPin(pet: pet, isSelected: pet.id == selectedID)
                .onTapGesture { withAnimation { selectedID = pet.id } }
                .accessibilityLabel("\(pet.name), \(pet.breed)")
                .accessibilityAddTraits(.isButton)
        } else {
            PetClusterBubble(count: cluster.pets.count)
                .onTapGesture { tapped(cluster) }
                .accessibilityLabel("\(cluster.pets.count) pets. Double tap to see them.")
                .accessibilityAddTraits(.isButton)
        }
    }

    /// Zoom in on a group, unless the pets are all at one address (zooming wouldn't separate them).
    private func tapped(_ cluster: PetCluster) {
        if cluster.isStacked {
            stack = cluster
            return
        }
        let span = visibleRegion?.span ?? MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: cluster.coordinate,
                span: MKCoordinateSpan(latitudeDelta: span.latitudeDelta / 3, longitudeDelta: span.longitudeDelta / 3)))
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.pfTextSecondary)
                TextField("Postcode or city", text: $placeText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await searchPlace() } }
                Button {
                    Task { await useMyLocation() }
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
                    ForEach(Self.radiusOptions, id: \.self) { miles in
                        PFChip(title: miles == 0 ? "Any distance" : DistanceUnit.current.label(miles: miles), isSelected: radius == miles) {
                            radius = miles
                            selectedID = nil
                            showRadius()
                        }
                    }
                    ForEach(Self.speciesOptions, id: \.self) { option in
                        PFChip(title: option, isSelected: species == option) {
                            species = species == option ? nil : option
                            selectedID = nil
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(.bar)
    }

    // MARK: - Bottom panel

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(spacing: Spacing.sm) {
            if let message {
                Text(message)
                    .font(.subheadline)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.medium))
            }
            if let pet = selectedPet {
                PetMapCard(pet: pet,
                           miles: center.flatMap { miles(from: $0, to: pet) },
                           close: { withAnimation { selectedID = nil } })
            } else {
                Text(summary)
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }

    private var summary: String {
        if !listings.isReady { return "Loading pets..." }
        let count: Int = visiblePets.count
        var text: String = count == 1 ? "1 pet on the map" : "\(count) pets on the map"
        let hidden: Int = listings.listings.count - withLocation.count
        if hidden > 0 { text += " · \(hidden) without a location" }
        return text
    }

    private func stackSheet(_ cluster: PetCluster) -> some View {
        NavigationStack {
            List(cluster.pets) { pet in
                Button {
                    stack = nil
                    router.push(.petDetail(pet))
                } label: {
                    HStack(spacing: Spacing.md) {
                        Color.clear
                            .frame(width: 56, height: 56)
                            .overlay { PetPhoto(url: pet.thumbnailURL, species: pet.species) }
                            .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pet.name).font(.pfHeadline).foregroundStyle(Color.pfTextPrimary)
                            Text(pet.breed).font(.subheadline).foregroundStyle(Color.pfTextSecondary)
                        }
                    }
                }
                .listRowBackground(Color.pfSurface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.pfBackground)
            .navigationTitle("\(cluster.pets.count) pets here")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { stack = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Location

    private func useMyLocation() async {
        message = nil
        do {
            let location = try await locationService.requestLocation()
            center = location.coordinate
            showRadius()
        } catch {
            message = error.localizedDescription
        }
    }

    private func searchPlace() async {
        let text = placeText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        message = nil
        guard let coordinate = await ShelterGeocoder.shared.coordinate(forLocationText: text) else {
            message = "Couldn't find \"\(text)\"."
            return
        }
        center = coordinate
        showRadius()
    }

    /// Frames the distance circle (or everything, for "Any distance").
    private func showRadius() {
        selectedID = nil
        withAnimation {
            if let center, radius > 0 {
                position = .region(MKCoordinateRegion(center: center, radiusMiles: Double(radius)))
            } else {
                position = .automatic
            }
        }
    }
}

// MARK: - Clustering

/// One pet, or several close together shown as a numbered bubble.
struct PetCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let pets: [Pet]

    var single: Pet? { pets.count == 1 ? pets.first : nil }

    /// True when every pet is at (almost exactly) the same place, which happens
    /// when one lister posts several pets. Zooming in can't separate them.
    var isStacked: Bool {
        guard let first = pets.first, let latitude = first.latitude, let longitude = first.longitude else { return false }
        return pets.allSatisfy { pet in
            abs((pet.latitude ?? latitude) - latitude) < 0.0003 && abs((pet.longitude ?? longitude) - longitude) < 0.0003
        }
    }

    /// Groups pets that would overlap at the current zoom into a grid of cells.
    static func make(from pets: [Pet], region: MKCoordinateRegion?) -> [PetCluster] {
        var placed: [(pet: Pet, coordinate: CLLocationCoordinate2D)] = []
        for pet in pets {
            if let latitude = pet.latitude, let longitude = pet.longitude {
                placed.append((pet, CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
            }
        }
        guard let region, region.span.latitudeDelta > 0, region.span.longitudeDelta > 0 else {
            return placed.map { PetCluster(id: $0.pet.id, coordinate: $0.coordinate, pets: [$0.pet]) }
        }

        // About 7 cells across and 10 down the screen.
        let cellLat = region.span.latitudeDelta / 10
        let cellLon = region.span.longitudeDelta / 7
        var cells: [String: [(pet: Pet, coordinate: CLLocationCoordinate2D)]] = [:]
        for item in placed {
            let row = Int(floor(item.coordinate.latitude / cellLat))
            let column = Int(floor(item.coordinate.longitude / cellLon))
            cells["\(row)_\(column)", default: []].append(item)
        }

        return cells.values.map { items in
            let latitude: Double = items.map { $0.coordinate.latitude }.reduce(0, +) / Double(items.count)
            let longitude: Double = items.map { $0.coordinate.longitude }.reduce(0, +) / Double(items.count)
            let ids: [String] = items.map { $0.pet.id }.sorted()
            return PetCluster(id: ids.joined(separator: "+"),
                              coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                              pets: items.map { $0.pet })
        }
    }
}

// MARK: - Pieces

/// The pet's photo as a round pin.
private struct PetPin: View {
    let pet: Pet
    let isSelected: Bool

    var body: some View {
        let size: CGFloat = isSelected ? 54 : 42
        Color.clear
            .frame(width: size, height: size)
            .overlay { PetPhoto(url: pet.thumbnailURL, species: pet.species) }
            .clipShape(Circle())
            .overlay(Circle().stroke(isSelected ? Color.pfBrandPrimary : Color.pfSurfaceElevated, lineWidth: 3))
            .shadow(radius: 2)
            .frame(width: 58, height: 58)
            .contentShape(Circle())
    }
}

private struct PetClusterBubble: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.pfSurfaceElevated)
            .frame(width: 46, height: 46)
            .background(Color.pfBrandPrimary, in: Circle())
            .overlay(Circle().stroke(Color.pfSurfaceElevated, lineWidth: 3))
            .shadow(radius: 2)
    }
}

/// The card that slides up when a pin is tapped; it opens the pet.
private struct PetMapCard: View {
    let pet: Pet
    let miles: Double?
    let close: () -> Void

    private var detail: String {
        var parts: [String] = [pet.breed]
        if !pet.location.isEmpty { parts.append(pet.location) }
        if let miles { parts.append(DistanceUnit.current.away(miles: miles)) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        PFCard {
            HStack(spacing: Spacing.md) {
                Color.clear
                    .frame(width: 72, height: 72)
                    .overlay { PetPhoto(url: pet.thumbnailURL, species: pet.species) }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(pet.name)
                            .font(.pfHeadline)
                            .foregroundStyle(Color.pfTextPrimary)
                        Spacer()
                        Button(action: close) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.pfTextSecondary)
                        }
                        .accessibilityLabel("Close")
                    }
                    Text(detail)
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                        .lineLimit(2)
                    NavigationLink(value: Route.petDetail(pet)) {
                        Text("Meet \(pet.name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.pfBrandPrimary)
                    }
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
