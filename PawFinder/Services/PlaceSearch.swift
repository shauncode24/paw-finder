import CoreLocation
import MapKit

/// A place found on the map (a park, a vet, an address someone searched for).
struct FoundPlace: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    var phone: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// For "Open in Maps" and directions.
    var mapItem: MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        item.phoneNumber = phone
        return item
    }

    init(name: String, address: String, coordinate: CLLocationCoordinate2D, phone: String? = nil) {
        self.name = name
        self.address = address
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        self.phone = phone
    }

    init(_ item: MKMapItem) {
        self.init(name: item.name ?? "Selected place",
                  address: item.placemark.title ?? "",
                  coordinate: item.placemark.coordinate,
                  phone: item.phoneNumber)
    }
}

/// The MapKit searches the app uses: text search for places near a point,
/// turning a typed suggestion into a place, and naming a dropped pin.
enum PlaceSearch {
    /// "dog park", "veterinarian"... near a point. Closest first.
    static func search(_ query: String, near center: CLLocationCoordinate2D, radiusMeters: Double = 8000) async -> [FoundPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: center, latitudinalMeters: radiusMeters * 2, longitudinalMeters: radiusMeters * 2)
        request.resultTypes = .pointOfInterest
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }

        let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let found: [FoundPlace] = response.mapItems.map { FoundPlace($0) }
        return found
            .filter { origin.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) <= radiusMeters * 1.5 }
            .sorted { first, second in
                let a = origin.distance(from: CLLocation(latitude: first.latitude, longitude: first.longitude))
                let b = origin.distance(from: CLLocation(latitude: second.latitude, longitude: second.longitude))
                return a < b
            }
    }

    /// Turns a suggestion from the search box into a real place.
    static func place(for completion: MKLocalSearchCompletion) async -> FoundPlace? {
        let request = MKLocalSearch.Request(completion: completion)
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return nil }
        return FoundPlace(item)
    }

    /// A name and address for wherever the pin is dropped.
    static func describe(_ coordinate: CLLocationCoordinate2D) async -> (name: String, address: String)? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        let parts: [String?] = [placemark.locality, placemark.administrativeArea]
        let address: String = parts.compactMap { $0 }.joined(separator: ", ")
        return (placemark.name ?? "Dropped pin", address)
    }

    /// A region that fits all the coordinates, with some room around them.
    static func region(fitting coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
                                    longitudeDelta: max((maxLon - minLon) * 1.4, 0.01))
        return MKCoordinateRegion(center: center, span: span)
    }
}

/// Live "as you type" suggestions for the search box.
@MainActor
@Observable
final class PlaceSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var results: [MKLocalSearchCompletion] = []
    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String, near region: MKCoordinateRegion?) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            results = []
            completer.queryFragment = ""
            return
        }
        if let region { completer.region = region }
        completer.queryFragment = trimmed
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let latest = completer.results
        Task { @MainActor in self.results = latest }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Log.location.notice("Place suggestions failed: \(error.localizedDescription)")
    }
}
