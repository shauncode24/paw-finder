import Foundation

/// A simple check before a message is sent: blocks abusive words and warns
/// about sharing payment details (a common adoption scam).
/// A real app would also moderate on the server.
enum ContentModerator {
    enum Verdict: Equatable {
        case ok
        case blocked(String)    // can't send
        case warning(String)    // can send after confirming
    }

    /// Keep this list short and obvious; it's a hook, not a full filter.
    private static let blockedWords = ["idiot", "stupid", "hate you", "shut up", "kill"]
    private static let paymentHints = ["wire transfer", "gift card", "western union", "bank details",
                                       "card number", "cvv", "send money", "paypal me", "zelle"]

    static func check(_ text: String) -> Verdict {
        let lower = text.lowercased()
        if blockedWords.contains(where: { lower.contains($0) }) {
            return .blocked("Please keep messages kind. This message can't be sent.")
        }
        if paymentHints.contains(where: { lower.contains($0) }) {
            return .warning("Never send money or card details before meeting the pet in person. Shelters take adoption fees at the shelter.")
        }
        return .ok
    }
}
