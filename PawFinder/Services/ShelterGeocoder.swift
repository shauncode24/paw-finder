import CoreLocation

/// Turns shelter addresses into map coordinates (Petfinder doesn't send them).
/// Results are saved to disk, because Apple's geocoder is slow and rate-limited
/// (roughly 50 lookups a minute), and shelters don't move.
@MainActor
final class ShelterGeocoder {
    static let shared = ShelterGeocoder()

    private struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double
    }

    private var cache: [String: Coordinate] = [:]   // shelter ID -> coordinate
    private let fileURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("shelter-coordinates.json")

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([String: Coordinate].self, from: data) {
            cache = saved
        }
    }

    func cachedCoordinate(for shelterID: String) -> CLLocationCoordinate2D? {
        cache[shelterID].map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// The shelter's coordinate, from the cache or by looking up its address.
    func coordinate(for shelter: Shelter) async -> CLLocationCoordinate2D? {
        if let cached = cachedCoordinate(for: shelter.id) { return cached }
        guard let coordinate = await coordinate(forAddress: shelter.geocodeQuery) else { return nil }
        cache[shelter.id] = Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
        save()
        return coordinate
    }

    /// Any address, ZIP code, or "City, ST" (not cached).
    func coordinate(forAddress address: String) async -> CLLocationCoordinate2D? {
        guard !address.isEmpty else { return nil }
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(address)
            return placemarks.first?.location?.coordinate
        } catch {
            Log.location.notice("Geocoding failed for an address: \(error.localizedDescription)")
            return nil
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
