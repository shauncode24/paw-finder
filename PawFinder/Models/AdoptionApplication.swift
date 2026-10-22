import Foundation

/// An application to adopt one pet: the form answers, documents, status
/// history, and (once approved) the "bring them home" checklist.
/// The adopter's copy lives on their phone; the lister gets the submitted
/// version in Firestore (`applications/{id}`) and updates its status there.
struct AdoptionApplication: Codable, Identifiable, Hashable {
    var id = UUID()
    var pet: Pet                         // snapshot, so it works offline
    var shelterName: String?
    var createdAt = Date.now
    var updatedAt = Date.now
    var submittedAt: Date?
    var status: ApplicationStatus = .draft
    var events: [ApplicationStatusEvent] = []
    var form = ApplicationForm()
    var attachments: [ApplicationAttachment] = []
    var checklist: [ChecklistItem] = []

    var isActive: Bool {
        [.submitted, .inReview, .interview, .approved].contains(status)
    }

    var isClosed: Bool {
        [.declined, .adopted, .withdrawn].contains(status)
    }
}

enum ApplicationStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case submitted = "Submitted"
    case inReview = "In review"
    case interview = "Interview"
    case approved = "Approved"
    case declined = "Declined"
    case adopted = "Adopted"
    case withdrawn = "Withdrawn"

    var icon: String {
        switch self {
        case .draft: "pencil"
        case .submitted: "paperplane.fill"
        case .inReview: "doc.text.magnifyingglass"
        case .interview: "person.2.fill"
        case .approved: "checkmark.seal.fill"
        case .declined: "xmark.octagon.fill"
        case .adopted: "house.fill"
        case .withdrawn: "arrow.uturn.backward"
        }
    }

    /// What this status means for the user.
    var explanation: String {
        switch self {
        case .draft: "Finish and submit your application when you're ready."
        case .submitted: "Your application was sent. The shelter will start reviewing it soon."
        case .inReview: "The shelter is reading your application and checking references."
        case .interview: "The shelter would like to talk and set up a meet-and-greet."
        case .approved: "You're approved! Get ready to bring your new friend home."
        case .declined: "The shelter couldn't approve this application. You can still apply for other pets."
        case .adopted: "Congratulations on your adoption!"
        case .withdrawn: "You withdrew this application."
        }
    }
}

struct ApplicationStatusEvent: Codable, Hashable, Identifiable {
    var id = UUID()
    let status: ApplicationStatus
    let date: Date
    var note: String?
}

/// The form answers, one group per step.
struct ApplicationForm: Codable, Equatable, Hashable {
    // About you
    var fullName = ""
    var email = ""
    var phone = ""
    var address = ""
    var isAdult = false

    // Home
    var homeType: AdopterProfile.HomeType?
    var ownsHome: Bool?                 // nil = not answered, false = renting
    var landlordAllowsPets = false
    var hasFencedYard = false
    var adultsInHome = 1
    var kids: AdopterProfile.KidsAtHome?

    // Pets & experience
    var currentPets = ""
    var experience: AdopterProfile.Experience?
    var vetName = ""
    var vetPhone = ""

    // Plans
    var hoursAlonePerDay = 4
    var whyThisPet = ""
    var preferredMeetTimes = ""

    // Agreements
    var agreesToHomeVisit = false
    var confirmsAccurate = false
}

struct ApplicationAttachment: Codable, Hashable, Identifiable {
    var id = UUID()
    let kind: Kind
    let fileName: String
    var addedAt = Date.now

    enum Kind: String, Codable, CaseIterable {
        case photoID = "Photo ID"
        case proofOfAddress = "Lease or proof of address"
        case vetReference = "Vet reference"
        case other = "Other"
    }
}

struct ChecklistItem: Codable, Hashable, Identifiable {
    var id = UUID()
    let title: String
    var isDone = false

    static let afterApproval: [ChecklistItem] = [
        "Buy food and bowls the shelter recommends",
        "Get a bed, collar or harness, and ID tag",
        "Pet-proof your home (cables, plants, small objects)",
        "Book a first vet visit for the first week",
        "Update the microchip registration with your details",
        "Look into pet insurance",
        "Plan the first few days at home: quiet space, routine",
    ].map { ChecklistItem(title: $0) }
}

// Short text summaries of the form, used by the review step and the tracker.
// Written out step by step so Swift compiles them quickly.
extension ApplicationForm {
    /// "House with a yard · Own"
    var homeSummary: String {
        var parts: [String] = []
        if let homeType {
            parts.append(homeType.rawValue)
        }
        if let ownsHome {
            parts.append(ownsHome ? "Own" : "Rent")
        }
        return parts.joined(separator: " · ")
    }

    /// "2 adults · Kids 6–12"
    var householdSummary: String {
        let adultWord: String = adultsInHome == 1 ? "adult" : "adults"
        var text: String = "\(adultsInHome) \(adultWord)"
        if let kids {
            text += " · \(kids.rawValue)"
        }
        return text
    }
}
