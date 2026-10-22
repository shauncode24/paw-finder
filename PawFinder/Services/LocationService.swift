import CoreLocation

/// Gets the user's location once, when they ask for it (e.g. "Use my location").
/// Phase 5 can grow this into continuous updates for the map.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum LocationError: LocalizedError {
        case denied
        case unavailable

        var errorDescription: String? {
            switch self {
            case .denied: "Location access is off. You can turn it on in Settings, or type a ZIP code instead."
            case .unavailable: "Couldn't find your location. Try again, or type a ZIP code instead."
            }
        }
    }

    private(set) var lastLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        authorizationStatus = .notDetermined
        super.init()
        authorizationStatus = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer   // city-level is plenty for pet search
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Asks for permission if needed, then returns the current location.
    func requestLocation() async throws -> CLLocation {
        if isDenied { throw LocationError.denied }
        // Only one request at a time.
        if let continuation { continuation.resume(throwing: LocationError.unavailable) }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            if authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()   // continues in locationManagerDidChangeAuthorization
            } else {
                manager.requestLocation()
            }
        }
    }

    private func finish(with result: Result<CLLocation, Error>) {
        if case .success(let location) = result { lastLocation = location }
        continuation?.resume(with: result)
        continuation = nil
    }

    // MARK: - CLLocationManagerDelegate (called by iOS, so not on our actor)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            guard continuation != nil else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.requestLocation()
            case .denied, .restricted:
                finish(with: .failure(LocationError.denied))
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in finish(with: .success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            Log.location.error("Location failed: \(error.localizedDescription)")
            finish(with: .failure(LocationError.unavailable))
        }
    }
}

extension CLLocation {
    /// "37.77,-122.42": a place written as text, which the listings search understands.
    var coordinateText: String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    /// Distance in miles to a coordinate.
    func miles(to coordinate: CLLocationCoordinate2D) -> Double {
        distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) / 1609.34
    }
}
