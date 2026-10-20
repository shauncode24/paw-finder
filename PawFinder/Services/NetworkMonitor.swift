import Network
import Observation

/// Tells the app whether the phone is online, so messages can wait in the
/// outbox and send when the connection comes back.
@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "PawFinder.NetworkMonitor"))
    }
}
