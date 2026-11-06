import Network
import Observation

/// Tells the app whether the phone is online, so messages can wait in the
/// outbox and send when the connection comes back.
///
/// It only says "offline" after the connection has been missing for a few
/// seconds, because iOS (and especially the Simulator) briefly reports "no
/// connection" while Wi-Fi is switching or the app is starting. A real outage
/// still shows the banner, just 3 seconds later.
@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var pendingOffline: Task<Void, Never>?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status != .unsatisfied
            Task { @MainActor in self?.update(online: online) }
        }
        monitor.start(queue: DispatchQueue(label: "PawFinder.NetworkMonitor"))
    }

    private func update(online: Bool) {
        pendingOffline?.cancel()
        if online {
            isOnline = true
            return
        }
        pendingOffline = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { isOnline = false }
        }
    }
}
