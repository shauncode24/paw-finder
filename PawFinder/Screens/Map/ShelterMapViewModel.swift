import CoreLocation
import MapKit

/// Finds shelters around a place and works out where to pin them.
@MainActor
@Observable
final class ShelterMapViewModel {
    enum State {
        case needsLocation      // nothing searched yet
        case loading
        case loaded
        case error(String)
    }

    private(set) var state: State = .needsLocation
    private(set) var shelters: [Shelter] = []
    /// Map pins appear as addresses are geocoded.
    private(set) var coordinates: [String: CLLocationCoordinate2D] = [:]
    private(set) var isGeocoding = false
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    /// Centre of the last search, used to decide when to offer "Search this area".
    private(set) var searchCenter: CLLocationCoordinate2D?

    // Filter chips
    var distance = 25 { didSet { saveDistance() } }
    var openNowOnly = false
    var followingOnly = false
    static let distanceOptions = [10, 25, 50, 100]

    private var searchLocation = ""
    private var page = 0
    private let repository: PetRepository

    init(repository: PetRepository) {
        self.repository = repository
        let saved = UserDefaults.standard.integer(forKey: "mapDistance")
        if Self.distanceOptions.contains(saved) { distance = saved }
    }

    /// Searches around a place. `location` is a ZIP, "City, ST", or "lat,long".
    func search(location: String, center: CLLocationCoordinate2D?, distance: Int? = nil) async {
        searchLocation = location
        searchCenter = center
        page = 0
        state = .loading
        do {
            let result = try await repository.fetchShelters(near: location, distance: distance ?? self.distance, page: 1)
            shelters = result.shelters
            page = result.currentPage
            hasMore = result.hasMore
            state = .loaded
            await geocodeMissing()
        } catch is CancellationError {
            // Replaced by a newer search.
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let result = try? await repository.fetchShelters(near: searchLocation, distance: distance, page: page + 1)
        else { return }
        let existing = Set(shelters.map(\.id))
        shelters += result.shelters.filter { !existing.contains($0.id) }
        page = result.currentPage
        hasMore = result.hasMore
        await geocodeMissing()
    }

    /// Shelters to show after applying the chips.
    func visibleShelters(followed: FollowedSheltersStore) -> [Shelter] {
        shelters.filter { shelter in
            if openNowOnly {
                guard case .open = shelter.openStatus() else { return false }
            }
            if followingOnly, !followed.isFollowing(shelter.id) { return false }
            return true
        }
    }

    /// Looks up pins one at a time (Apple's geocoder doesn't like bursts).
    /// Already-known shelters come straight from the saved cache.
    private func geocodeMissing() async {
        isGeocoding = true
        defer { isGeocoding = false }
        for shelter in shelters where coordinates[shelter.id] == nil {
            if Task.isCancelled { return }
            if let coordinate = await ShelterGeocoder.shared.coordinate(for: shelter) {
                coordinates[shelter.id] = coordinate
            }
        }
    }

    private func saveDistance() {
        UserDefaults.standard.set(distance, forKey: "mapDistance")
    }
}

/// A map pin for one shelter, or a bubble for several close together.
struct ShelterCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let shelters: [Shelter]

    /// Groups pins that would overlap at the current zoom into a grid of cells.
    static func make(from shelters: [Shelter],
                     coordinates: [String: CLLocationCoordinate2D],
                     region: MKCoordinateRegion?) -> [ShelterCluster] {
        let pinned = shelters.compactMap { shelter in coordinates[shelter.id].map { (shelter, $0) } }
        guard let region, region.span.latitudeDelta > 0, region.span.longitudeDelta > 0 else {
            return pinned.map { ShelterCluster(id: $0.0.id, coordinate: $0.1, shelters: [$0.0]) }
        }

        // About 6 cells across and 9 down the screen.
        let cellLat = region.span.latitudeDelta / 9
        let cellLon = region.span.longitudeDelta / 6
        var cells: [String: [(Shelter, CLLocationCoordinate2D)]] = [:]
        for item in pinned {
            let key = "\(Int(floor(item.1.latitude / cellLat)))_\(Int(floor(item.1.longitude / cellLon)))"
            cells[key, default: []].append(item)
        }

        return cells.values.map { items in
            let latitude = items.map(\.1.latitude).reduce(0, +) / Double(items.count)
            let longitude = items.map(\.1.longitude).reduce(0, +) / Double(items.count)
            let ids = items.map(\.0.id).sorted()
            return ShelterCluster(id: ids.joined(separator: "+"),
                                  coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                  shelters: items.map(\.0))
        }
    }
}

extension MKCoordinateRegion {
    /// A region about `miles` across each way from the centre.
    init(center: CLLocationCoordinate2D, radiusMiles miles: Double) {
        let degrees = miles / 69 * 2
        self.init(center: center, span: MKCoordinateSpan(latitudeDelta: degrees, longitudeDelta: degrees))
    }

    /// Roughly how far the visible area reaches from the centre, in miles.
    var radiusMiles: Double { span.latitudeDelta * 69 / 2 }
}
