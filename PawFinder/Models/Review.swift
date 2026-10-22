import FirebaseFirestore
import Foundation

/// An adopter's review of a lister, written after an adoption is complete.
/// Stored in `reviews/{applicationID}`: the application's ID is the review's ID,
/// which is what makes it one review per adoption.
struct Review: Identifiable, Hashable {
    /// The application's ID (uppercase UUID text).
    let id: String
    let listerID: String
    let reviewerID: String
    var reviewerName: String
    var petName: String
    var rating: Int
    var text: String
    var createdAt: Date
    var updatedAt: Date?
    /// The lister's public reply, if they wrote one.
    var reply: String?
    var repliedAt: Date?

    static let maxTextLength = 500
    /// How long the adopter can edit their review.
    static let editWindow: TimeInterval = 7 * 24 * 3600

    /// The reviewer can still change it for a week.
    var isEditable: Bool { Date.now < createdAt.addingTimeInterval(Self.editWindow) }

    var wasEdited: Bool {
        guard let updatedAt else { return false }
        return updatedAt.timeIntervalSince(createdAt) > 60
    }

    init?(id: String, data d: [String: Any]) {
        guard let listerID = d["listerID"] as? String,
              let reviewerID = d["reviewerID"] as? String,
              let rating = d["rating"] as? Int else { return nil }
        self.id = id
        self.listerID = listerID
        self.reviewerID = reviewerID
        self.rating = min(max(rating, 1), 5)
        reviewerName = (d["reviewerName"] as? String) ?? ""
        petName = (d["petName"] as? String) ?? ""
        text = (d["text"] as? String) ?? ""
        createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? .now
        updatedAt = (d["updatedAt"] as? Timestamp)?.dateValue()
        let replyText = (d["reply"] as? String) ?? ""
        reply = replyText.isEmpty ? nil : replyText
        repliedAt = (d["repliedAt"] as? Timestamp)?.dateValue()
    }

    /// "Priya S." rather than a full name on a public page.
    var shortName: String {
        let parts = reviewerName.split(separator: " ")
        guard let first = parts.first else { return "An adopter" }
        guard parts.count > 1, let initial = parts.last?.first else { return String(first) }
        return "\(first) \(initial)."
    }
}

/// A lister's average rating, kept on their `users/{uid}` document as a running
/// total so no screen has to read every review.
struct RatingSummary: Hashable {
    var sum = 0
    var count = 0

    var average: Double? { count > 0 ? Double(sum) / Double(count) : nil }

    /// "4.8"
    var averageText: String? {
        average.map { String(format: "%.1f", $0) }
    }

    /// "4.8 (12 reviews)"
    var label: String? {
        guard let averageText else { return nil }
        return "\(averageText) (\(count) \(count == 1 ? "review" : "reviews"))"
    }
}
