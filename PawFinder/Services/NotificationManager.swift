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
