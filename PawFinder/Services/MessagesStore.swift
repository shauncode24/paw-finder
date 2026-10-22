import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

/// Real chat between adopters and listers, over Firestore.
///
/// How it behaves like a socket: `addSnapshotListener` keeps a live connection
/// open to Firestore, so a message sent from one phone shows up on the other
/// within a moment, with no polling. Writes made offline are queued by Firestore
/// and delivered automatically when the phone reconnects (the "outbox").
///
/// Listeners only run while the app is open. When it's closed, `backgroundCheck()`
/// (run by iOS's background refresh) looks for new messages and posts a local
/// notification. Instant push to a closed app would need a server (Cloud
/// Functions); see docs/Listers-and-Messaging.md.
@MainActor
@Observable
final class MessagesStore {
    private(set) var conversations: [Conversation] = []
    private(set) var isLoaded = false
    private(set) var userID: String?

    /// Messages waiting for me, across all chats (not counting blocked ones).
    var unreadCount: Int {
        guard let userID else { return 0 }
        return conversations.filter { !$0.isBlocked }.map { $0.unreadCount(for: userID) }.reduce(0, +)
    }

    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private let notifiedKey = "lastNotifiedMessageTimes"
    /// Meet-up reminders already scheduled on this phone (chat ID -> meet-up time).
    @ObservationIgnored private var scheduledMeetups: [String: Date] = [:]

    private var isConfigured: Bool { FirebaseApp.app() != nil }
    private var db: Firestore { Firestore.firestore() }

    // MARK: - Listening

    /// Call whenever the signed-in user changes (nil = signed out).
    func start(for uid: String?) {
        guard uid != userID else { return }
        listener?.remove()
        listener = nil
        conversations = []
        isLoaded = false
        userID = uid
        scheduledMeetups = [:]

        guard isConfigured, let uid else { return }
        listener = db.collection("conversations")
            .whereField("participants", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error { Log.network.error("Chats listener: \(error.localizedDescription)") }
                Task { @MainActor in self?.handle(snapshot, uid: uid) }
            }
    }

    private func handle(_ snapshot: QuerySnapshot?, uid: String) {
        guard let snapshot, userID == uid else { return }

        // New message from the other person while the app is open and that chat isn't on screen.
        if isLoaded {
            for change in snapshot.documentChanges where change.type != .removed {
                guard !change.document.metadata.hasPendingWrites,
                      let conversation = Conversation(id: change.document.documentID,
                                                      data: change.document.data(with: .estimate)) else { continue }
                notifyIfNew(conversation, me: uid)
            }
        }

        conversations = snapshot.documents
            .compactMap { Conversation(id: $0.documentID, data: $0.data(with: .estimate)) }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
        isLoaded = true
        updateMeetupReminders()
    }

    /// The next accepted meet-up, soonest first, across all chats.
    var upcomingMeetups: [Conversation] {
        conversations
            .filter { ($0.nextMeetupAt ?? .distantPast) > .now && !$0.isBlocked }
            .sorted { ($0.nextMeetupAt ?? .distantFuture) < ($1.nextMeetupAt ?? .distantFuture) }
    }

    /// Keeps one reminder per accepted meet-up (an hour before), on both phones,
    /// and removes it when the meet-up is cancelled.
    private func updateMeetupReminders() {
        let me = userID ?? ""
        for chat in conversations {
            guard let at = chat.nextMeetupAt, at > .now, !chat.isBlocked, scheduledMeetups[chat.id] != at else { continue }
            scheduledMeetups[chat.id] = at
            let place = chat.nextMeetupPlace ?? "the meeting spot"
            let other = chat.otherName(for: me)
            Task {
                await NotificationManager.shared.scheduleMeetupReminder(
                    conversationID: chat.id, place: place, petName: chat.listingName, with: other, at: at)
            }
        }
        for id in Array(scheduledMeetups.keys) where conversation(id)?.nextMeetupAt == nil {
            scheduledMeetups[id] = nil
            NotificationManager.shared.cancelMeetupReminder(conversationID: id)
        }
    }

    func conversation(_ id: String) -> Conversation? {
        conversations.first { $0.id == id }
    }

    // MARK: - Starting a chat

    /// Opens the chat about a pet, creating it the first time.
    /// - Returns: the conversation ID.
    func openConversation(listingID: String, listingName: String, listingSpecies: String,
                          adopterID: String, adopterName: String,
                          listerID: String, listerName: String) async throws -> String {
        guard isConfigured else { throw APIError.notConfigured }
        guard userID != nil else { throw APIError.notSignedIn }
        guard adopterID != listerID else { throw BackendMessage(text: "You can't message yourself.") }

        let id = Conversation.makeID(listingID: listingID, adopterID: adopterID)
        let reference = db.collection("conversations").document(id)
        do {
            let existing = try await reference.getDocument()
            if !existing.exists {
                let conversation = Conversation(id: id, listingID: listingID, listingName: listingName,
                                                listingSpecies: listingSpecies, adopterID: adopterID,
                                                adopterName: adopterName, listerID: listerID, listerName: listerName)
                // No `await`: offline, Firestore queues this and sends it later.
                reference.setData(conversation.newDocumentData, completion: nil)
            }
        } catch {
            throw backendError(error)
        }
        return id
    }

    // MARK: - Sending and reading

    /// Sends a message. Never waits for the network: Firestore shows it
    /// immediately as "pending" and delivers it when it can.
    func send(text: String?, photo: Data?, in conversationID: String) {
        guard let userID, let conversation = conversation(conversationID), !conversation.isBlocked else { return }
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmed ?? "").isEmpty
        guard hasText || photo != nil else { return }

        let conversationRef = db.collection("conversations").document(conversationID)
        let messageRef = conversationRef.collection("messages").document()

        var message: [String: Any] = ["senderID": userID, "createdAt": FieldValue.serverTimestamp()]
        if hasText, let trimmed { message["text"] = trimmed }
        if let photo { message["image"] = photo.base64EncodedString() }

        let other = conversation.otherID(for: userID)
        let preview: String = hasText ? (trimmed ?? "") : "📷 Photo"

        let batch = db.batch()
        batch.setData(message, forDocument: messageRef)
        batch.updateData([
            "lastMessage": preview,
            "lastMessageAt": FieldValue.serverTimestamp(),
            "lastSenderID": userID,
            "unread.\(other)": FieldValue.increment(Int64(1)),
            "typing.\(userID)": FieldValue.delete(),
        ], forDocument: conversationRef)
        batch.commit(completion: nil)
    }

    // MARK: - Meet-ups

    /// Sends a meet-up proposal. Pass `replacing` to answer someone else's
    /// proposal with a different place or time (the old one becomes "changed").
    func proposeMeetup(_ meetup: Meetup, replacing oldMessageID: String? = nil, in conversationID: String) {
        guard let userID, let conversation = conversation(conversationID), !conversation.isBlocked else { return }
        let conversationRef = db.collection("conversations").document(conversationID)
        let messageRef = conversationRef.collection("messages").document()
        let other = conversation.otherID(for: userID)

        let batch = db.batch()
        batch.setData(["senderID": userID, "createdAt": FieldValue.serverTimestamp(), "meetup": meetup.data],
                      forDocument: messageRef)
        if let oldMessageID {
            batch.updateData(["meetup.status": MeetupStatus.changed.rawValue],
                             forDocument: conversationRef.collection("messages").document(oldMessageID))
        }
        batch.updateData([
            "lastMessage": "📍 Meet-up: \(meetup.summary)",
            "lastMessageAt": FieldValue.serverTimestamp(),
            "lastSenderID": userID,
            "unread.\(other)": FieldValue.increment(Int64(1)),
            "typing.\(userID)": FieldValue.delete(),
        ], forDocument: conversationRef)
        batch.commit(completion: nil)
    }

    /// Accepts or declines a proposal (or cancels one that was already accepted).
    func respondToMeetup(messageID: String, meetup: Meetup, accept: Bool, in conversationID: String) {
        guard let userID, let conversation = conversation(conversationID), !conversation.isBlocked else { return }
        let conversationRef = db.collection("conversations").document(conversationID)
        let messageRef = conversationRef.collection("messages").document(messageID)
        let other = conversation.otherID(for: userID)

        var update: [String: Any] = [
            "lastMessageAt": FieldValue.serverTimestamp(),
            "lastSenderID": userID,
            "unread.\(other)": FieldValue.increment(Int64(1)),
        ]
        if accept {
            update["lastMessage"] = "✅ Meet-up accepted: \(meetup.summary)"
            update["nextMeetupAt"] = Timestamp(date: meetup.date)
            update["nextMeetupPlace"] = meetup.placeName
        } else {
            let wasAccepted = meetup.status == .accepted
            update["lastMessage"] = wasAccepted ? "Meet-up cancelled: \(meetup.placeName)" : "Meet-up declined: \(meetup.placeName)"
            if wasAccepted {
                update["nextMeetupAt"] = FieldValue.delete()
                update["nextMeetupPlace"] = FieldValue.delete()
            }
        }

        let batch = db.batch()
        batch.updateData(["meetup.status": (accept ? MeetupStatus.accepted : MeetupStatus.declined).rawValue],
                         forDocument: messageRef)
        batch.updateData(update, forDocument: conversationRef)
        batch.commit(completion: nil)
    }

    /// Tells the other person I've seen everything (this is what makes "Read" appear for them).
    func markRead(_ conversationID: String) {
        guard let userID, conversation(conversationID) != nil else { return }
        db.collection("conversations").document(conversationID).updateData([
            "unread.\(userID)": 0,
            "lastRead.\(userID)": FieldValue.serverTimestamp(),
        ], completion: nil)
    }

    /// Shows or clears "typing…" on the other person's screen.
    func setTyping(_ isTyping: Bool, in conversationID: String) {
        guard let userID else { return }
        let value: Any = isTyping ? FieldValue.serverTimestamp() : FieldValue.delete()
        db.collection("conversations").document(conversationID).updateData(["typing.\(userID)": value], completion: nil)
    }

    // MARK: - Safety

    func setBlocked(_ blocked: Bool, _ conversationID: String) {
        guard let userID else { return }
        let change: Any = blocked ? FieldValue.arrayUnion([userID]) : FieldValue.arrayRemove([userID])
        db.collection("conversations").document(conversationID).updateData(["blockedBy": change], completion: nil)
    }

    /// Reports a chat (or one message in it). Saved in Firestore for a moderator to read.
    func report(_ conversationID: String, reason: String, messageID: String? = nil) {
        var data: [String: Any] = [
            "type": "conversation",
            "conversationID": conversationID,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let messageID { data["messageID"] = messageID }
        if let userID { data["reporterID"] = userID }
        db.collection("reports").addDocument(data: data, completion: nil)
    }

    // MARK: - Notifications

    /// Posts a notification once per new message from the other person.
    private func notifyIfNew(_ conversation: Conversation, me: String) {
        guard conversation.lastSenderID != me, conversation.lastSenderID != "",
              conversation.unreadCount(for: me) > 0, !conversation.isBlocked else { return }
        var seen = UserDefaults.standard.dictionary(forKey: notifiedKey) as? [String: Double] ?? [:]
        let stamp = conversation.lastMessageAt.timeIntervalSince1970
        guard stamp > (seen[conversation.id] ?? 0) else { return }
        seen[conversation.id] = stamp
        UserDefaults.standard.set(seen, forKey: notifiedKey)

        Task {
            await NotificationManager.shared.notifyIncomingMessage(
                conversationID: conversation.id,
                from: conversation.otherName(for: me),
                about: conversation.listingName,
                text: conversation.lastMessage
            )
        }
    }

    /// Run by iOS's background refresh: one quick look for messages that arrived
    /// while the app was closed.
    func backgroundCheck() async {
        guard isConfigured, let uid = Auth.auth().currentUser?.uid else { return }
        let snapshot = try? await db.collection("conversations")
            .whereField("participants", arrayContains: uid)
            .getDocuments()
        for document in snapshot?.documents ?? [] {
            if let conversation = Conversation(id: document.documentID, data: document.data(with: .estimate)) {
                notifyIfNew(conversation, me: uid)
            }
        }
    }
}
