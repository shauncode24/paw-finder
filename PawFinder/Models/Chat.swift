import FirebaseFirestore
import Foundation

/// A chat between an adopter and a lister, about one pet.
///
/// Stored in `conversations/{id}` where id = "<listingID>_<adopterID>", so there
/// is exactly one chat per adopter per pet and no search is needed to find it.
/// The messages themselves are in `conversations/{id}/messages/{messageID}`.
struct Conversation: Identifiable, Hashable {
    let id: String
    var listingID: String
    var listingName: String
    var listingSpecies: String
    var adopterID: String
    var adopterName: String
    var listerID: String
    var listerName: String

    var lastMessage = ""
    var lastMessageAt: Date = .distantPast
    var lastSenderID = ""
    /// How many messages each person hasn't read yet, by user ID.
    var unread: [String: Int] = [:]
    /// When each person last looked at the chat (this is what "Read" is based on).
    var lastRead: [String: Date] = [:]
    /// When each person last typed (shown as "typing…" for a few seconds).
    var typing: [String: Date] = [:]
    var blockedBy: [String] = []
    var createdAt: Date = .now
    /// An accepted meet-up that hasn't happened yet (set when someone accepts one).
    var nextMeetupAt: Date?
    var nextMeetupPlace: String?

    static func makeID(listingID: String, adopterID: String) -> String {
        "\(listingID)_\(adopterID)"
    }

    func otherID(for me: String) -> String { me == adopterID ? listerID : adopterID }
    func otherName(for me: String) -> String {
        let name = me == adopterID ? listerName : adopterName
        return name.isEmpty ? "Someone" : name
    }
    func unreadCount(for me: String) -> Int { unread[me] ?? 0 }
    var isBlocked: Bool { !blockedBy.isEmpty }
    func isBlockedByMe(_ me: String) -> Bool { blockedBy.contains(me) }

    /// "Asking about Luna" (for adopters) or "Luna" (for the lister).
    func subtitle(for me: String) -> String {
        me == listerID ? "About \(listingName) · \(adopterName)" : "About \(listingName)"
    }

    // MARK: Firestore

    init(id: String, listingID: String, listingName: String, listingSpecies: String,
         adopterID: String, adopterName: String, listerID: String, listerName: String) {
        self.id = id
        self.listingID = listingID
        self.listingName = listingName
        self.listingSpecies = listingSpecies
        self.adopterID = adopterID
        self.adopterName = adopterName
        self.listerID = listerID
        self.listerName = listerName
    }

    init?(id: String, data d: [String: Any]) {
        guard let listingID = d["listingID"] as? String,
              let adopterID = d["adopterID"] as? String,
              let listerID = d["listerID"] as? String else { return nil }
        self.init(id: id, listingID: listingID, listingName: (d["listingName"] as? String) ?? "a pet",
                  listingSpecies: (d["listingSpecies"] as? String) ?? "Dog",
                  adopterID: adopterID, adopterName: (d["adopterName"] as? String) ?? "",
                  listerID: listerID, listerName: (d["listerName"] as? String) ?? "")
        lastMessage = (d["lastMessage"] as? String) ?? ""
        lastMessageAt = (d["lastMessageAt"] as? Timestamp)?.dateValue() ?? .now
        lastSenderID = (d["lastSenderID"] as? String) ?? ""
        blockedBy = (d["blockedBy"] as? [String]) ?? []
        createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? .now
        nextMeetupAt = (d["nextMeetupAt"] as? Timestamp)?.dateValue()
        nextMeetupPlace = d["nextMeetupPlace"] as? String
        for (user, value) in (d["unread"] as? [String: Any]) ?? [:] {
            unread[user] = (value as? Int) ?? 0
        }
        for (user, value) in (d["lastRead"] as? [String: Any]) ?? [:] {
            if let stamp = value as? Timestamp { lastRead[user] = stamp.dateValue() }
        }
        for (user, value) in (d["typing"] as? [String: Any]) ?? [:] {
            if let stamp = value as? Timestamp { typing[user] = stamp.dateValue() }
        }
    }

    /// The document written when a chat is first opened.
    var newDocumentData: [String: Any] {
        [
            "listingID": listingID,
            "listingName": listingName,
            "listingSpecies": listingSpecies,
            "adopterID": adopterID,
            "adopterName": adopterName,
            "listerID": listerID,
            "listerName": listerName,
            "participants": [adopterID, listerID],
            "lastMessage": "",
            "lastMessageAt": FieldValue.serverTimestamp(),
            "lastSenderID": "",
            "unread": [adopterID: 0, listerID: 0],
            "blockedBy": [String](),
            "createdAt": FieldValue.serverTimestamp(),
        ]
    }
}

/// One message in a chat.
struct ChatMessage: Identifiable, Hashable {
    let id: String
    let senderID: String
    var text: String?
    /// The photo, as base64 text (decoded only when shown).
    var imageBase64: String?
    /// Set when this message is a meet-up proposal rather than text.
    var meetup: Meetup?
    /// When the server received it. For a message still being sent, an estimate.
    var createdAt: Date
    /// True while the message is still on this phone (offline or sending).
    var isPending: Bool

    init?(id: String, data d: [String: Any], isPending: Bool) {
        guard let senderID = d["senderID"] as? String else { return nil }
        self.id = id
        self.senderID = senderID
        text = d["text"] as? String
        imageBase64 = d["image"] as? String
        meetup = (d["meetup"] as? [String: Any]).flatMap { Meetup(data: $0) }
        createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? .now
        self.isPending = isPending
    }
}
