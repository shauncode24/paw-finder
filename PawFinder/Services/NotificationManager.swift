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
    @ObservationIgnored var openConversationID: String?

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
            let name = favorite.pet.name
            let body: String
            if !favorite.isListed {
                body = "\(name)'s listing was removed. They may have found a home."
            } else if favorite.pet.isAdopted {
                body = "\(name) has been adopted!"
            } else if favorite.pet.isPending {
                body = "\(name) now has an adoption pending."
            } else {
                body = "\(name) is available again."
            }
            await deliver(.favorites, id: "status-\(favorite.id)", title: "Update on \(name)", body: body,
                          link: "pawfinder://pet/\(favorite.id)")
        }
    }

    /// "3 new pets from Sunny Paws Rescue" for each followed lister with new listings.
    func notifyNewArrivals(_ arrivals: [FollowedSheltersStore.NewArrivals]) async {
        for arrival in arrivals {
            let count = arrival.pets.count
            await deliver(.shelters, id: "arrivals-\(arrival.shelter.id)",
                          title: count == 1 ? "New pet from \(arrival.shelter.name)" : "\(count) new pets from \(arrival.shelter.name)",
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

    /// An adopter's application was updated by the lister ("Luna: Interview").
    func notifyApplicationUpdate(applicationID: UUID, petName: String, status: ApplicationStatus, note: String?) async {
        await deliver(.applications, id: "application-\(applicationID.uuidString)-\(status.rawValue)",
                      title: "\(petName): \(status.rawValue)",
                      body: note ?? status.explanation,
                      link: "pawfinder://application/\(applicationID.uuidString)")
    }

    /// A lister received a new application.
    func notifyNewApplication(applicationID: String, petName: String, applicantName: String) async {
        await deliver(.applications, id: "received-\(applicationID)",
                      title: "New application for \(petName)",
                      body: "\(applicantName) would like to adopt \(petName).",
                      link: "pawfinder://received/\(applicationID)")
    }

    /// A chat message arrived from the other person.
    func notifyIncomingMessage(conversationID: String, from sender: String, about petName: String, text: String) async {
        await deliver(.messages, id: "message-\(conversationID)",
                      title: sender, body: text.isEmpty ? "Sent you a message about \(petName)." : text,
                      link: "pawfinder://conversation/\(conversationID)",
                      extraInfo: ["conversationID": conversationID])
    }

    /// Reminders for the Week 1, Month 1 and Month 3 check-ins of an adoption journey.
    /// Reusing the same ID replaces the old reminder, so calling this again is safe.
    func scheduleJourneyReminders(applicationID: String, petName: String, adoptedAt: Date) async {
        for milestone in JourneyMilestone.allCases where milestone != .day1 {
            let due = milestone.dueDate(adoptedAt: adoptedAt)
            guard due > .now.addingTimeInterval(5) else { continue }
            await deliver(.journey, id: "journey-\(applicationID)-\(milestone.rawValue)",
                          title: "\(petName): \(milestone.shortTitle) check-in",
                          body: milestone.reminderText(for: petName),
                          link: "pawfinder://journey/\(applicationID)", at: due)
        }
    }

    /// "Meet Luna at Central Park in an hour." One per chat, an hour before the meet-up.
    /// Skipped when that moment has passed or quiet hours would push it past the meet-up.
    func scheduleMeetupReminder(conversationID: String, place: String, petName: String,
                                with other: String, at meetupDate: Date) async {
        let reminder = meetupDate.addingTimeInterval(-3600)
        guard reminder > .now.addingTimeInterval(5),
              NotificationPreferences.current.deliveryDate(for: reminder) < meetupDate else { return }
        await deliver(.messages, id: "meetup-\(conversationID)",
                      title: "Meet \(petName) in an hour",
                      body: "\(place) with \(other), at \(meetupDate.formatted(date: .omitted, time: .shortened)).",
                      link: "pawfinder://conversation/\(conversationID)", at: reminder,
                      extraInfo: ["conversationID": conversationID])
    }

    func cancelMeetupReminder(conversationID: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["meetup-\(conversationID)"])
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
            let isOpenChat = conversationID != nil && conversationID == openConversationID
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
