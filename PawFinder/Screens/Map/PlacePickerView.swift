import MapKit
import SwiftUI

/// Pick a meeting place and time for a meet & greet.
///
/// Three ways to choose a spot: type in the search box (suggestions appear as
/// you type), tap a shortcut such as "Dog parks" and pick one of the pins, or
/// just move the map: the pin stays in the middle and the address follows it.
struct PlacePickerView: View {
    /// Where to start looking: the pet's area, if known.
    let startCoordinate: CLLocationCoordinate2D?
    let me: String
    let onPick: (Meetup) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(LocationService.self) private var locationService

    @State private var position: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var chosen: CLLocationCoordinate2D?
    @State private var placeName = ""
    @State private var address = ""
    @State private var query = ""
    @State private var completer = PlaceSearchCompleter()
    @State private var suggestions: [FoundPlace] = []
    @State private var activeShortcut: String?
    @State private var isSearching = false
    @State private var noResults = false
    @State private var date: Date = PlacePickerView.defaultDate()
    @State private var geocodeTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    private static let shortcuts: [(title: String, query: String, icon: String)] = [
        ("Dog parks", "dog park", "tree"),
        ("Cafés", "cafe", "cup.and.saucer"),
        ("Vets", "veterinarian", "cross.case"),
        ("Pet stores", "pet store", "bag"),
    ]

    /// Tomorrow at 4 PM, a reasonable first guess.
    private static func defaultDate() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        return calendar.date(bySettingHour: 16, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private var center: CLLocationCoordinate2D? { visibleRegion?.center ?? startCoordinate }
    private var canSend: Bool {
        !placeName.trimmingCharacters(in: .whitespaces).isEmpty && center != nil && date > .now
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                ZStack(alignment: .top) {
                    map
                    if !query.isEmpty { completionList }
                }
                bottomPanel
            }
            .background(Color.pfBackground)
            .navigationTitle("Pick a meeting place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await moveToStart() }
            .onChange(of: query) { completer.update(query: query, near: visibleRegion) }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.pfTextSecondary)
                TextField("Search for a place or address", text: $query)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.pfTextSecondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(Spacing.md)
            .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
            .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(Self.shortcuts, id: \.title) { shortcut in
                        PFChip(title: shortcut.title, isSelected: activeShortcut == shortcut.title) {
                            Task { await runShortcut(shortcut.title, query: shortcut.query) }
                        }
                    }
                    if isSearching { ProgressView() }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(.bar)
    }

    /// Suggestions that appear while typing.
    private var completionList: some View {
        List(completer.results.prefix(8).map { CompletionRow(completion: $0) }) { row in
            Button {
                Task { await choose(completion: row.completion) }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.completion.title).foregroundStyle(Color.pfTextPrimary)
                    if !row.completion.subtitle.isEmpty {
                        Text(row.completion.subtitle)
                            .font(.pfCaption)
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                }
            }
            .listRowBackground(Color.pfSurface)
        }
        .listStyle(.plain)
        .frame(maxHeight: 360)
        .overlay {
            if completer.results.isEmpty {
                Text("Searching...").font(.subheadline).foregroundStyle(Color.pfTextSecondary)
            }
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(suggestions) { place in
                Annotation(place.name, coordinate: place.coordinate) {
                    Button {
                        choose(place)
                    } label: {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundStyle(Color.pfBrandPrimary, Color.pfSurfaceElevated)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(place.name)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: MapCameraUpdateFrequency.onEnd) { context in
            cameraMoved(to: context.region)
        }
        // The pin stays in the middle of the screen; its tip is the chosen spot.
        .overlay {
            Image(systemName: "mappin")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.pfBrandPrimary)
                .shadow(radius: 2)
                .offset(y: -17)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .center) {
            if noResults {
                Text("Nothing found nearby. Try moving the map.")
                    .font(.subheadline)
                    .padding(Spacing.md)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.medium))
            }
        }
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TextField("Place name", text: $placeName)
                .font(.pfHeadline)
            if !address.isEmpty {
                Text(address)
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
                    .lineLimit(2)
            }
            DatePicker("When", selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
            Text("Meet in a public place, in daylight if you can, and bring a friend if you like. You don't have to share your home address.")
                .font(.pfCaption)
                .foregroundStyle(Color.pfTextSecondary)
            PFButton(title: "Send proposal", action: send)
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.5)
        }
        .padding(Spacing.lg)
        .background(.bar)
    }

    // MARK: - Actions

    /// Start on the user's location, else the pet's area.
    private func moveToStart() async {
        if let startCoordinate {
            position = .region(MKCoordinateRegion(center: startCoordinate, latitudinalMeters: 6000, longitudinalMeters: 6000))
        }
        if let location = try? await locationService.requestLocation() {
            position = .region(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 6000, longitudinalMeters: 6000))
        }
    }

    private func cameraMoved(to region: MKCoordinateRegion) {
        visibleRegion = region
        // A search result moved the camera: keep its name.
        if let chosen, CLLocation(latitude: chosen.latitude, longitude: chosen.longitude)
            .distance(from: CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)) < 40 {
            return
        }
        chosen = nil
        noResults = false
        geocodeTask?.cancel()
        geocodeTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let found = await PlaceSearch.describe(region.center) else { return }
            placeName = found.name
            address = found.address
        }
    }

    private func choose(_ place: FoundPlace) {
        searchFocused = false
        chosen = place.coordinate
        placeName = place.name
        address = place.address
        withAnimation {
            position = .region(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 800, longitudinalMeters: 800))
        }
    }

    private func choose(completion: MKLocalSearchCompletion) async {
        guard let place = await PlaceSearch.place(for: completion) else { return }
        query = ""
        suggestions = []
        activeShortcut = nil
        choose(place)
    }

    private func runShortcut(_ title: String, query text: String) async {
        guard let center else { return }
        activeShortcut = title
        isSearching = true
        noResults = false
        defer { isSearching = false }
        let found = await PlaceSearch.search(text, near: center)
        suggestions = Array(found.prefix(12))
        noResults = found.isEmpty
        if let region = PlaceSearch.region(fitting: suggestions.map(\.coordinate)) {
            withAnimation { position = .region(region) }
        }
    }

    private func send() {
        guard let center, canSend else { return }
        let point = chosen ?? center
        let meetup = Meetup(placeName: placeName.trimmingCharacters(in: .whitespaces),
                            address: address,
                            coordinate: point,
                            date: date,
                            proposedBy: me)
        onPick(meetup)
        dismiss()
    }
}

/// Wraps a suggestion so `List` can identify it.
private struct CompletionRow: Identifiable {
    let completion: MKLocalSearchCompletion
    var id: String { completion.title + "|" + completion.subtitle }
}
