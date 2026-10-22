import FirebaseFirestore
import Foundation

/// An application as the lister sees it (an adopter applied for one of their pets).
/// Stored in `applications/{id}`; the adopter's phone and the lister's phone
/// both read it live, and the lister changes its status.
struct ReceivedApplication: Identifiable, Hashable {
    let id: String                 // same as the adopter's local application ID
    let listingID: String
    let petName: String
    let petSpecies: String
    let adopterID: String
    let adopterName: String
    var status: ApplicationStatus
    var events: [ApplicationStatusEvent]
    var form: ApplicationForm
    var submittedAt: Date

    init?(id: String, data d: [String: Any]) {
        guard let listingID = d["listingID"] as? String,
              let adopterID = d["adopterID"] as? String else { return nil }
        self.id = id
        self.listingID = listingID
        self.adopterID = adopterID
        petName = (d["petName"] as? String) ?? "a pet"
        petSpecies = (d["petSpecies"] as? String) ?? "Dog"
        adopterName = (d["adopterName"] as? String) ?? "An adopter"
        status = ApplicationStatus(rawValue: (d["status"] as? String) ?? "") ?? .submitted
        events = ApplicationJSON.events(from: d["events"])
        form = ApplicationJSON.form(from: d["formJSON"]) ?? ApplicationForm()
        submittedAt = (d["submittedAt"] as? Timestamp)?.dateValue() ?? .now
    }
}

/// Applications keep their form and status history as JSON text inside the
/// Firestore document. That avoids converting every field by hand.
enum ApplicationJSON {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func text<T: Encodable>(_ value: T) -> String {
        guard let data = try? encoder.encode(value) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func form(from value: Any?) -> ApplicationForm? {
        guard let text = value as? String, let data = text.data(using: .utf8) else { return nil }
        return try? decoder.decode(ApplicationForm.self, from: data)
    }

    static func events(from value: Any?) -> [ApplicationStatusEvent] {
        let texts = (value as? [String]) ?? []
        let events: [ApplicationStatusEvent] = texts.compactMap { text in
            guard let data = text.data(using: .utf8) else { return nil }
            return try? decoder.decode(ApplicationStatusEvent.self, from: data)
        }
        return events.sorted { $0.date < $1.date }
    }
}
