import Foundation

/// A chat with a shelter, usually about one pet.
struct Conversation: Codable, Identifiable, Hashable {
    var id = UUID()
    let shelterID: String
    var shelterName: String
    var pet: Pet?                       // snapshot; nil when started from the shelter page
    var messages: [Message] = []
    /// Simulated shelter replies waiting for their time (see MessagesStore).
    var pendingReplies: [ScheduledReply] = []
    var lastReadAt = Date.distantPast
    var isBlocked = false
    var createdAt = Date.now

    var title: String { shelterName }
    var subtitle: String? { pet.map { "About \($0.name)" } }

    var lastMessage: Message? { messages.last }

    var unreadCount: Int {
        messages.filter { $0.sender == .shelter && $0.date > lastReadAt }.count
    }
}

struct Message: Codable, Identifiable, Hashable {
    var id = UUID()
    let sender: Sender
    var text: String?
    var imageFile: String?              // file in Documents/MessageFiles/
    /// When it was written. For the user's messages this is also when it was queued.
    let date: Date
    /// When it actually left the phone. nil = waiting in the outbox (offline).
    var sentAt: Date?
    /// When the (simulated) shelter read it.
    var readAt: Date?

    enum Sender: String, Codable {
        case me, shelter, system
    }

    enum Status {
        case waiting, sent, delivered, read
    }

    /// Delivery status for the user's own messages, worked out from the times.
    func status(at now: Date = .now) -> Status {
        guard let sentAt else { return .waiting }
        if let readAt, readAt <= now { return .read }
        return now.timeIntervalSince(sentAt) >= 1 ? .delivered : .sent
    }
}

struct ScheduledReply: Codable, Hashable, Identifiable {
    var id = UUID()
    let date: Date
    let text: String

    /// The shelter shows "typing…" for a few seconds before the reply lands.
    func isTyping(at now: Date) -> Bool {
        now < date && now >= date.addingTimeInterval(-4)
    }
}
