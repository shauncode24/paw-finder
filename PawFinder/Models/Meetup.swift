import CoreLocation
import FirebaseFirestore
import Foundation

/// Where a meet-up stands. Only the person who did *not* propose it can accept or decline.
enum MeetupStatus: String {
    case proposed
    case accepted
    case declined
    /// The other person suggested a different place or time instead.
    case changed

    var label: String {
        switch self {
        case .proposed: "Proposed"
        case .accepted: "Accepted"
        case .declined: "Declined"
        case .changed: "Changed"
        }
    }

    var icon: String {
        switch self {
        case .proposed: "clock"
        case .accepted: "checkmark.circle.fill"
        case .declined: "xmark.circle"
        case .changed: "arrow.triangle.2.circlepath"
        }
    }
}

/// A suggested place and time to meet a pet (a "meet & greet"). It is sent as a
/// special chat message: `conversations/{id}/messages/{id}` with a `meetup` map.
struct Meetup: Hashable {
    var placeName: String
    var address: String
    var latitude: Double
    var longitude: Double
    var date: Date
    var status: MeetupStatus = .proposed
    /// User ID of the person who suggested it.
    var proposedBy: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// "Sat 14 Dec, 4:30 PM"
    var dateText: String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }

    /// One line for chat previews and notifications.
    var summary: String { "\(placeName) · \(dateText)" }

    var isUpcoming: Bool { date > .now }

    init(placeName: String, address: String, coordinate: CLLocationCoordinate2D, date: Date, proposedBy: String) {
        self.placeName = placeName
        self.address = address
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        self.date = date
        self.proposedBy = proposedBy
    }

    init?(data d: [String: Any]) {
        guard let placeName = d["placeName"] as? String,
              let latitude = d["latitude"] as? Double,
              let longitude = d["longitude"] as? Double,
              let proposedBy = d["proposedBy"] as? String else { return nil }
        self.placeName = placeName
        address = (d["address"] as? String) ?? ""
        self.latitude = latitude
        self.longitude = longitude
        date = (d["date"] as? Timestamp)?.dateValue() ?? .now
        status = MeetupStatus(rawValue: (d["status"] as? String) ?? "") ?? .proposed
        self.proposedBy = proposedBy
    }

    /// The map stored in the message document.
    var data: [String: Any] {
        [
            "placeName": placeName,
            "address": address,
            "latitude": latitude,
            "longitude": longitude,
            "date": Timestamp(date: date),
            "status": status.rawValue,
            "proposedBy": proposedBy,
        ]
    }
}
