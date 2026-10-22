import CoreLocation

/// Turns places into map coordinates with Apple's geocoder (which is slow and
/// limited to roughly 50 lookups a minute, so answers are remembered).
///
/// Listers already store an approximate position on their profile, so the map
/// mostly doesn't need this; it's used for the postcode/city someone types
/// into a search, and as a fallback for profiles without coordinates.
@MainActor
final class ShelterGeocoder {
    static let shared = ShelterGeocoder()

    private struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double
    }

    private var cache: [String: Coordinate] = [:]   // lister ID or address text -> coordinate
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

    /// The lister's coordinate: saved on their profile, else looked up from their city/postcode.
    func coordinate(for shelter: Shelter) async -> CLLocationCoordinate2D? {
        if let latitude = shelter.latitude, let longitude = shelter.longitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        if let cached = cachedCoordinate(for: shelter.id) { return cached }
        guard let coordinate = await coordinate(forAddress: shelter.geocodeQuery) else { return nil }
        cache[shelter.id] = Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
        save()
        return coordinate
    }

    /// Any address, postcode, or "City, ST". Answers are remembered.
    func coordinate(forAddress address: String) async -> CLLocationCoordinate2D? {
        let key = "address:" + address.trimmingCharacters(in: .whitespaces).lowercased()
        guard key.count > "address:".count else { return nil }
        if let cached = cache[key] {
            return CLLocationCoordinate2D(latitude: cached.latitude, longitude: cached.longitude)
        }
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(address)
            guard let coordinate = placemarks.first?.location?.coordinate else { return nil }
            cache[key] = Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            save()
            return coordinate
        } catch {
            Log.location.notice("Geocoding failed for an address: \(error.localizedDescription)")
            return nil
        }
    }

    /// Turns what someone typed or picked into a coordinate: "12.97,77.59" is
    /// used as is; anything else (a postcode, "City, ST") is looked up.
    func coordinate(forLocationText text: String) async -> CLLocationCoordinate2D? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let numbers: [Double?] = trimmed.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        if numbers.count == 2, let latitude = numbers[0], let longitude = numbers[1] {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        return await coordinate(forAddress: trimmed)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
