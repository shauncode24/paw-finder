import UserNotifications

/// Local notifications (no server needed): "Biscuit has been adopted", etc.
/// Tapping one opens the pet through a deep link.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Set by the app so notification taps can navigate.
    var onOpenURL: ((URL) -> Void)?

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Shows the system permission prompt the first time only.
    func requestAuthorizationIfNeeded() async {
        guard await authorizationStatus() == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Log.notifications.error("Permission request failed: \(error.localizedDescription)")
        }
    }

    /// One notification per favorite whose status changed.
    func notifyStatusChanges(_ favorites: [FavoritePet]) async {
        guard await authorizationStatus() == .authorized else { return }
        for favorite in favorites {
            let content = UNMutableNotificationContent()
            content.title = "Update on \(favorite.pet.name)"
            content.body = favorite.isListed && favorite.pet.isAdopted
                ? "\(favorite.pet.name) has been adopted!"
                : "\(favorite.pet.name)'s listing was removed. They may have found a home."
            content.sound = .default
            content.userInfo = ["url": "pawfinder://pet/\(favorite.id)"]

            let request = UNNotificationRequest(identifier: "status-\(favorite.id)", content: content, trigger: nil)
            try? await center.add(request)
        }
    }

    /// "3 new pets at Austin Animal Center" for each followed shelter with new listings.
    func notifyNewArrivals(_ arrivals: [FollowedSheltersStore.NewArrivals]) async {
        guard await authorizationStatus() == .authorized else { return }
        for arrival in arrivals {
            let content = UNMutableNotificationContent()
            let count = arrival.pets.count
            content.title = count == 1 ? "New pet at \(arrival.shelter.name)" : "\(count) new pets at \(arrival.shelter.name)"
            content.body = arrival.pets.prefix(3).map(\.name).joined(separator: ", ")
                + (count > 3 ? " and more" : "") + " just arrived."
            content.sound = .default
            content.userInfo = ["url": "pawfinder://shelter/\(arrival.shelter.id)"]

            let request = UNNotificationRequest(identifier: "arrivals-\(arrival.shelter.id)", content: content, trigger: nil)
            try? await center.add(request)
        }
    }

    /// Schedules a notification for each planned (simulated) shelter reply.
    func scheduleApplicationUpdates(_ application: AdoptionApplication) async {
        await requestAuthorizationIfNeeded()
        guard await authorizationStatus() == .authorized else { return }
        for event in application.scheduledEvents {
            let content = UNMutableNotificationContent()
            content.title = "\(application.pet.name): \(event.status.rawValue)"
            content.body = event.note ?? event.status.explanation
            content.sound = .default
            content.userInfo = ["url": "pawfinder://application/\(application.id.uuidString)"]

            let seconds = max(1, event.date.timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            let request = UNNotificationRequest(identifier: Self.applicationNotificationID(application.id, event.status),
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancelApplicationUpdates(_ applicationID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: ApplicationStatus.allCases.map { Self.applicationNotificationID(applicationID, $0) }
        )
    }

    func cancelApplicationUpdate(_ applicationID: UUID, status: ApplicationStatus) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.applicationNotificationID(applicationID, status)])
    }

    private static func applicationNotificationID(_ id: UUID, _ status: ApplicationStatus) -> String {
        "application-\(id.uuidString)-\(status.rawValue)"
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banners even when the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let link = response.notification.request.content.userInfo["url"] as? String
        Task { @MainActor in
            if let link, let url = URL(string: link) { onOpenURL?(url) }
            completionHandler()
        }
    }
}
