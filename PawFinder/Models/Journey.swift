import FirebaseFirestore
import Foundation

/// The adoption journey of one pet after it goes home: check-ins at Day 1,
/// Week 1, Month 1 and Month 3, and photo updates the adopter can share.
/// Stored in `journeys/{applicationID}` (the application's ID is the journey's ID).
struct Journey: Identifiable, Hashable {
    let id: String
    let adopterID: String
    let listerID: String
    let listingID: String
    var petName: String
    var petSpecies: String
    var adoptedAt: Date
    /// The adopter lets the lister feature updates as "Happy tails" on their profile.
    var shareHappyTails: Bool

    init?(id: String, data d: [String: Any]) {
        guard let adopterID = d["adopterID"] as? String,
              let listerID = d["listerID"] as? String else { return nil }
        self.id = id
        self.adopterID = adopterID
        self.listerID = listerID
        listingID = (d["listingID"] as? String) ?? ""
        petName = (d["petName"] as? String) ?? "your pet"
        petSpecies = (d["petSpecies"] as? String) ?? "Dog"
        adoptedAt = (d["adoptedAt"] as? Timestamp)?.dateValue() ?? .now
        shareHappyTails = (d["shareHappyTails"] as? Bool) ?? true
    }

    /// "Day 12": the day of the journey, counting the adoption day as Day 1.
    func dayNumber(on date: Date = .now) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: adoptedAt),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        return max(days, 0) + 1
    }
}

/// A photo and a few words the adopter posted to the journey.
struct JourneyUpdate: Identifiable, Hashable {
    let id: String
    var text: String
    /// The photo as base64 text (decoded only when shown).
    var photoBase64: String?
    var createdAt: Date
    var isPending: Bool

    init?(id: String, data d: [String: Any], isPending: Bool) {
        guard d["authorID"] is String else { return nil }
        self.id = id
        text = (d["text"] as? String) ?? ""
        photoBase64 = d["photo"] as? String
        createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? .now
        self.isPending = isPending
    }
}

/// An update the lister chose to show on their profile. Stored in
/// `happyTails/{updateID}`; it has only the pet's name, never the adopter's.
struct HappyTail: Identifiable, Hashable {
    let id: String
    let applicationID: String
    let listerID: String
    var petName: String
    var text: String
    var photoBase64: String?
    var createdAt: Date

    init?(id: String, data d: [String: Any]) {
        guard let listerID = d["listerID"] as? String else { return nil }
        self.id = id
        self.listerID = listerID
        applicationID = (d["applicationID"] as? String) ?? ""
        petName = (d["petName"] as? String) ?? "A pet"
        text = (d["text"] as? String) ?? ""
        photoBase64 = d["photo"] as? String
        createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? .now
    }
}

// MARK: - Check-ins

/// One thing to do at a check-in, optionally with a Care Hub guide that helps.
struct JourneyTask: Identifiable, Hashable {
    let id: String
    let title: String
    let articleID: String?
}

/// The four check-ins after adoption.
enum JourneyMilestone: String, CaseIterable, Identifiable {
    case day1, week1, month1, month3

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .day1: "Day 1"
        case .week1: "Week 1"
        case .month1: "Month 1"
        case .month3: "Month 3"
        }
    }

    var title: String {
        switch self {
        case .day1: "Welcome home"
        case .week1: "Settling in"
        case .month1: "One month together"
        case .month3: "Part of the family"
        }
    }

    var icon: String {
        switch self {
        case .day1: "house.fill"
        case .week1: "calendar"
        case .month1: "heart.fill"
        case .month3: "star.fill"
        }
    }

    /// Days after the adoption day when the check-in is due.
    var offsetDays: Int {
        switch self {
        case .day1: 0
        case .week1: 7
        case .month1: 30
        case .month3: 90
        }
    }

    /// 10 in the morning on the day it is due.
    func dueDate(adoptedAt: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: offsetDays, to: calendar.startOfDay(for: adoptedAt)) ?? adoptedAt
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day) ?? day
    }

    func reminderText(for petName: String) -> String {
        switch self {
        case .day1: "\(petName) is home. Take it slow today."
        case .week1: "It's been a week. How is \(petName) settling in?"
        case .month1: "A month together! Time for a quick check-in on \(petName)."
        case .month3: "Three months with \(petName). Share how it's going."
        }
    }

    /// Short checklists; the guides they link to are in the Care Hub.
    var tasks: [JourneyTask] {
        switch self {
        case .day1:
            [
                JourneyTask(id: "space", title: "Set up a quiet space with food, water and a bed", articleID: "first-week"),
                JourneyTask(id: "calm", title: "Keep the first day calm, with few visitors", articleID: nil),
                JourneyTask(id: "notes", title: "Note when they eat, drink and go to the toilet", articleID: nil),
                JourneyTask(id: "message", title: "Tell the lister they got home safely", articleID: nil),
            ]
        case .week1:
            [
                JourneyTask(id: "vet", title: "Book the first vet visit", articleID: "vet"),
                JourneyTask(id: "routine", title: "Settle into a daily routine for meals and walks", articleID: "first-week"),
                JourneyTask(id: "training", title: "Start gentle training", articleID: "training"),
                JourneyTask(id: "pets", title: "Introduce other pets slowly", articleID: "intro-pets"),
            ]
        case .month1:
            [
                JourneyTask(id: "records", title: "Check vaccines and microchip details are up to date", articleID: "vet"),
                JourneyTask(id: "costs", title: "Review what your pet really costs each month", articleID: "budget"),
                JourneyTask(id: "photo", title: "Share a photo update", articleID: nil),
            ]
        case .month3:
            [
                JourneyTask(id: "yearly", title: "Plan the yearly vet visit and any licensing", articleID: "vet"),
                JourneyTask(id: "review", title: "Leave a review for the lister", articleID: nil),
                JourneyTask(id: "celebrate", title: "Celebrate three months together", articleID: nil),
            ]
        }
    }
}
