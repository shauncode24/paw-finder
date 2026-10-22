import MapKit
import SwiftUI

/// The meeting spot on a map, with the route from where you are, travel time
/// for driving, walking or transit, a street-level Look Around preview, and a
/// button to continue in Apple Maps.
struct MeetupMapView: View {
    let meetup: Meetup

    @Environment(LocationService.self) private var locationService

    enum Transport: String, CaseIterable, Identifiable {
        case driving = "Drive"
        case walking = "Walk"
        case transit = "Transit"

        var id: String { rawValue }

        var type: MKDirectionsTransportType {
            switch self {
            case .driving: .automobile
            case .walking: .walking
            case .transit: .transit
            }
        }

        var launchMode: String {
            switch self {
            case .driving: MKLaunchOptionsDirectionsModeDriving
            case .walking: MKLaunchOptionsDirectionsModeWalking
            case .transit: MKLaunchOptionsDirectionsModeTransit
            }
        }
    }

    @State private var transport: Transport = .driving
    @State private var position: MapCameraPosition = .automatic
    @State private var route: MKRoute?
    @State private var travelTime: TimeInterval?
    @State private var distanceMeters: Double?
    @State private var message: String?
    @State private var isLoading = false
    @State private var lookAroundScene: MKLookAroundScene?

    private var destination: MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: meetup.coordinate))
        item.name = meetup.placeName
        return item
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                map
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    transportPicker
                    travelInfo
                    if let lookAroundScene {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Street view")
                                .font(.pfHeadline)
                                .foregroundStyle(Color.pfTextPrimary)
                            LookAroundPreview(initialScene: lookAroundScene, allowsNavigation: false)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                        }
                    }
                    PFButton(title: "Open in Apple Maps") {
                        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: transport.launchMode])
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.pfBackground)
        .navigationTitle("Meet-up")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: transport) { await loadRoute() }
        .task { await loadLookAround() }
    }

    // MARK: - Pieces

    private var map: some View {
        Map(position: $position) {
            UserAnnotation()
            Marker(meetup.placeName, systemImage: "pawprint.fill", coordinate: meetup.coordinate)
                .tint(Color.pfBrandPrimary)
            if let route {
                MapPolyline(route)
                    .stroke(Color.pfBrandPrimary, lineWidth: 5)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .frame(height: 320)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(meetup.placeName)
                .font(.pfTitle)
                .foregroundStyle(Color.pfTextPrimary)
            if !meetup.address.isEmpty {
                Text(meetup.address)
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
            }
            Label(meetup.dateText, systemImage: "calendar")
                .foregroundStyle(Color.pfTextPrimary)
            Label(meetup.status.label, systemImage: meetup.status.icon)
                .font(.subheadline)
                .foregroundStyle(meetup.status == .accepted ? Color.pfSuccess : Color.pfTextSecondary)
        }
    }

    private var transportPicker: some View {
        Picker("How you're getting there", selection: $transport) {
            ForEach(Transport.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var travelInfo: some View {
        PFCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if isLoading {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text("Finding the best route...").foregroundStyle(Color.pfTextSecondary)
                    }
                } else if let travelTime {
                    Text(Self.durationText(travelTime))
                        .font(.title2.bold())
                        .foregroundStyle(Color.pfTextPrimary)
                    if let distanceMeters {
                        Text(Measurement(value: distanceMeters, unit: UnitLength.meters)
                            .formatted(.measurement(width: .abbreviated, usage: .road)))
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                    if meetup.isUpcoming {
                        let leaveBy = meetup.date.addingTimeInterval(-travelTime)
                        Label("Leave by \(leaveBy.formatted(date: .omitted, time: .shortened)) to arrive on time",
                              systemImage: "figure.walk.departure")
                            .font(.subheadline)
                            .foregroundStyle(Color.pfTextPrimary)
                    }
                }
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Color.pfTextSecondary)
                }
            }
        }
    }

    // MARK: - Loading

    private func loadRoute() async {
        route = nil
        travelTime = nil
        distanceMeters = nil
        message = nil
        isLoading = true
        defer { isLoading = false }

        var origin = locationService.lastLocation
        if origin == nil { origin = try? await locationService.requestLocation() }
        guard let origin else {
            message = "Turn on location to see the route and travel time from where you are."
            showSpot()
            return
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        request.destination = destination
        request.transportType = transport.type
        let directions = MKDirections(request: request)

        do {
            if transport == .transit {
                // Apple only draws transit routes in the Maps app; here we show the estimate.
                let estimate = try await directions.calculateETA()
                travelTime = estimate.expectedTravelTime
                distanceMeters = estimate.distance
                message = "Transit stops and times are in Apple Maps."
                fit([origin.coordinate, meetup.coordinate])
            } else {
                let response = try await directions.calculate()
                guard let best = response.routes.first else {
                    message = "No route found."
                    showSpot()
                    return
                }
                route = best
                travelTime = best.expectedTravelTime
                distanceMeters = best.distance
                let rect = best.polyline.boundingMapRect
                withAnimation {
                    position = .rect(rect.insetBy(dx: -rect.width * 0.25, dy: -rect.height * 0.25))
                }
            }
        } catch {
            message = "No \(transport.rawValue.lowercased()) route found from where you are."
            showSpot()
        }
    }

    private func showSpot() {
        withAnimation {
            position = .region(MKCoordinateRegion(center: meetup.coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200))
        }
    }

    private func fit(_ coordinates: [CLLocationCoordinate2D]) {
        guard let region = PlaceSearch.region(fitting: coordinates) else { return }
        withAnimation { position = .region(region) }
    }

    /// Street-level imagery exists only in some places; the section is hidden otherwise.
    private func loadLookAround() async {
        let request = MKLookAroundSceneRequest(coordinate: meetup.coordinate)
        lookAroundScene = try? await request.scene
    }

    /// "12 min" or "1 h 5 min".
    static func durationText(_ seconds: TimeInterval) -> String {
        let minutes = max(Int((seconds / 60).rounded()), 1)
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }
}
