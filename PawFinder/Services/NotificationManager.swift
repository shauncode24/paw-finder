import UserNotifications

/// Local notifications (no server needed): adoptions, new arrivals, saved
/// search matches, application updates, and shelter replies.
///
/// - Every notification goes through `deliver(...)`, which respects the
///   user's per-category switches and quiet hours (`NotificationPreferences`).
/// - Before the system permission prompt, the app shows its own short
///   explanation (`primingCategory` → `NotificationPrimingView`).
/// - Tapping a notification opens its deep link.
@MainActor
@Observable
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Set by the app so notification taps can navigate.
    @ObservationIgnored var onOpenURL: ((URL) -> Void)?
    /// The chat on screen right now; its message notifications aren't shown.
    @ObservationIgnored var openConversationID: UUID?

    /// When set, the app shows the "turn on notifications?" explanation sheet.
    var primingCategory: NotificationPreferences.Category?

    @ObservationIgnored private let center = UNUserNotificationCenter.current()
    private static let primingDeclinedKey = "notificationPrimingDeclinedAt"

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Permission

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Call when the user does something notifications would help with
    /// (favoriting, following, applying, messaging, saving a search).
    /// Shows our explanation first; the system prompt comes only if they agree.
    /// If they said "Not now", we wait 3 days before asking again.
    func askPermission(for category: NotificationPreferences.Category) async {
        guard await authorizationStatus() == .notDetermined, primingCategory == nil else { return }
        if let declined = UserDefaults.standard.object(forKey: Self.primingDeclinedKey) as? Date,
           Date.now.timeIntervalSince(declined) < 3 * 24 * 60 * 60 { return }
        primingCategory = category
    }

    /// "Turn on notifications" in the explanation sheet.
    func acceptPriming() async {
        primingCategory = nil
        await requestSystemPermission()
    }

    /// "Not now" in the explanation sheet.
    func declinePriming() {
        primingCategory = nil
        UserDefaults.standard.set(Date.now, forKey: Self.primingDeclinedKey)
    }

    /// The system prompt (only shows the first time).
    func requestSystemPermission() async {
        guard await authorizationStatus() == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Log.notifications.error("Permission request failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sending

    /// The one place notifications are scheduled.
    /// - Parameters:
    ///   - date: When it should appear (nil = now). Moved out of quiet hours if needed.
    ///   - id: Reusing an id replaces the pending notification with that id.
    private func deliver(_ category: NotificationPreferences.Category, id: String, title: String, body: String,
                         link: String, at date: Date? = nil, extraInfo: [String: String] = [:]) async {
        let preferences = NotificationPreferences.current
        guard preferences.isOn(category), await authorizationStatus() == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = category.rawValue
        content.userInfo = extraInfo.merging(["url": link]) { $1 }

        let fireDate = preferences.deliveryDate(for: date ?? .now)
        let seconds = fireDate.timeIntervalSinceNow
        let trigger = seconds > 1 ? UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false) : nil
        do {
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        } catch {
            Log.notifications.error("Couldn't schedule a notification: \(error.localizedDescription)")
        }
    }

    /// One notification per favorite whose status changed.
    func notifyStatusChanges(_ favorites: [FavoritePet]) async {
        for favorite in favorites {
            await deliver(.favorites, id: "status-\(favorite.id)",
                          title: "Update on \(favorite.pet.name)",
                          body: favorite.isListed && favorite.pet.isAdopted
                              ? "\(favorite.pet.name) has been adopted!"
                              : "\(favorite.pet.name)'s listing was removed. They may have found a home.",
                          link: "pawfinder://pet/\(favorite.id)")
        }
    }

    /// "3 new pets at Austin Animal Center" for each followed shelter with new listings.
    func notifyNewArrivals(_ arrivals: [FollowedSheltersStore.NewArrivals]) async {
        for arrival in arrivals {
            let count = arrival.pets.count
            await deliver(.shelters, id: "arrivals-\(arrival.shelter.id)",
                          title: count == 1 ? "New pet at \(arrival.shelter.name)" : "\(count) new pets at \(arrival.shelter.name)",
                          body: Self.nameList(arrival.pets) + " just arrived.",
                          link: "pawfinder://shelter/\(arrival.shelter.id)")
        }
    }

    /// "4 new pets match 'Senior Cat near 78702'".
    func notifySavedSearchMatches(_ matches: [SavedSearchesStore.NewMatches]) async {
        for match in matches {
            let count = match.pets.count
            await deliver(.savedSearches, id: "search-\(match.search.id.uuidString)",
                          title: count == 1 ? "New match: \(match.search.name)" : "\(count) new matches: \(match.search.name)",
                          body: "Meet " + Self.nameList(match.pets) + ".",
                          link: "pawfinder://search/\(match.search.id.uuidString)")
        }
    }

    /// Schedules a notification for each planned (simulated) shelter reply.
    func scheduleApplicationUpdates(_ application: AdoptionApplication) async {
        for event in application.scheduledEvents {
            await deliver(.applications, id: Self.applicationNotificationID(application.id, event.status),
                          title: "\(application.pet.name): \(event.status.rawValue)",
                          body: event.note ?? event.status.explanation,
                          link: "pawfinder://application/\(application.id.uuidString)",
                          at: event.date)
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

    /// Notification for a simulated shelter reply, shown if you're not in that chat.
    /// One pending notification per chat: a newer reply replaces it.
    func scheduleMessageReply(_ reply: ScheduledReply, in conversation: Conversation) async {
        await deliver(.messages, id: "message-\(conversation.id.uuidString)",
                      title: conversation.shelterName, body: reply.text,
                      link: "pawfinder://conversation/\(conversation.id.uuidString)",
                      at: reply.date, extraInfo: ["conversationID": conversation.id.uuidString])
    }

    func cancelMessageNotifications(for conversationID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["message-\(conversationID.uuidString)"])
    }

    /// From Settings, to check everything works. Ignores quiet hours.
    func sendTestNotification() async {
        guard await authorizationStatus() == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "PawFinder"
        content.body = "Notifications are working. 🐾"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger))
    }

    /// The number on the app icon.
    func updateBadge(_ count: Int) {
        Task { try? await center.setBadgeCount(count) }
    }

    /// "Biscuit, Luna, Milo and 2 more"
    private static func nameList(_ pets: [Pet]) -> String {
        let names = pets.prefix(3).map(\.name).joined(separator: ", ")
        return pets.count > 3 ? "\(names) and \(pets.count - 3) more" : names
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banners even when the app is open, except for the chat you're looking at.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let conversationID = notification.request.content.userInfo["conversationID"] as? String
        Task { @MainActor in
            let isOpenChat = conversationID != nil && conversationID == openConversationID?.uuidString
            completionHandler(isOpenChat ? [] : [.banner, .sound])
        }
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
