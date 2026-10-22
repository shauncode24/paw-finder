import MapKit
import SwiftUI

/// Vets, pet stores, dog parks and groomers near you, from Apple Maps.
/// Reached from the Care Hub and from the "Welcome home" screen.
struct NearbyPlacesView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case vets = "Vets"
        case stores = "Pet stores"
        case parks = "Dog parks"
        case groomers = "Groomers"

        var id: String { rawValue }

        var query: String {
            switch self {
            case .vets: "veterinarian"
            case .stores: "pet store"
            case .parks: "dog park"
            case .groomers: "pet groomer"
            }
        }

        var icon: String {
            switch self {
            case .vets: "cross.case.fill"
            case .stores: "bag.fill"
            case .parks: "tree.fill"
            case .groomers: "scissors"
            }
        }
    }

    @Environment(LocationService.self) private var locationService
    @State private var kind: Kind = .vets
    @State private var places: [FoundPlace] = []
    @State private var origin: CLLocationCoordinate2D?
    @State private var selectedID: UUID?
    @State private var position: MapCameraPosition = .automatic
    @State private var isLoading = false
    @State private var message: String?

    private var selected: FoundPlace? { places.first { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Kind of place", selection: $kind) {
                ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(Spacing.lg)

            map
                .frame(height: 260)

            list
        }
        .background(Color.pfBackground)
        .navigationTitle("Near you")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: kind) { await load() }
    }

    private var map: some View {
        Map(position: $position, selection: $selectedID) {
            UserAnnotation()
            ForEach(places) { place in
                Marker(place.name, systemImage: kind.icon, coordinate: place.coordinate)
                    .tint(Color.pfBrandPrimary)
                    .tag(place.id)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }

    private var list: some View {
        List {
            if isLoading {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("Searching Apple Maps...").foregroundStyle(Color.pfTextSecondary)
                }
                .listRowBackground(Color.pfSurface)
            }
            if let message {
                Text(message)
                    .foregroundStyle(Color.pfTextSecondary)
                    .listRowBackground(Color.pfSurface)
            }
            ForEach(places) { place in
                row(place)
                    .listRowBackground(place.id == selectedID ? Color.pfBrandDeep : Color.pfSurface)
                    .contentShape(Rectangle())
                    .onTapGesture { select(place) }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func row(_ place: FoundPlace) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(place.name)
                .font(.pfHeadline)
                .foregroundStyle(Color.pfTextPrimary)
            let details = detailLine(place)
            if !details.isEmpty {
                Text(details)
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
            }
            HStack(spacing: Spacing.lg) {
                Button {
                    place.mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                } label: {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }
                if let phone = place.phone, let url = Self.phoneURL(phone) {
                    Link(destination: url) {
                        Label("Call", systemImage: "phone.fill")
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderless)
        }
        .padding(.vertical, Spacing.xs)
    }

    /// "1.4 mi · 12 Main St, Austin"
    private func detailLine(_ place: FoundPlace) -> String {
        var parts: [String] = []
        if let origin {
            let miles = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
                .miles(to: place.coordinate)
            parts.append(String(format: "%.1f mi", miles))
        }
        if !place.address.isEmpty { parts.append(place.address) }
        return parts.joined(separator: " · ")
    }

    private func select(_ place: FoundPlace) {
        selectedID = place.id
        withAnimation {
            position = .region(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500))
        }
    }

    private func load() async {
        places = []
        selectedID = nil
        message = nil
        isLoading = true
        defer { isLoading = false }

        var location = locationService.lastLocation
        if location == nil { location = try? await locationService.requestLocation() }
        guard let location else {
            message = "Turn on location to find places near you."
            return
        }
        origin = location.coordinate
        position = .region(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 8000, longitudinalMeters: 8000))

        let found = await PlaceSearch.search(kind.query, near: location.coordinate, radiusMeters: 10000)
        places = Array(found.prefix(20))
        if places.isEmpty {
            message = "Nothing found within about 6 miles."
        } else if let region = PlaceSearch.region(fitting: places.prefix(8).map(\.coordinate) + [location.coordinate]) {
            withAnimation { position = .region(region) }
        }
    }

    /// "tel:" links need digits only.
    private static func phoneURL(_ phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }
}
