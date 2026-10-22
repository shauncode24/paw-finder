import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

/// Reads and writes adoption journeys (`journeys/{applicationID}`), their photo
/// updates (`journeys/{id}/updates/{updateID}`), and the "Happy tails" a lister
/// chooses to show on their profile (`happyTails/{updateID}`).
///
/// Photos are stored inside the documents as base64 text (no paid Storage plan).
enum JourneyService {
    private static var db: Firestore { Firestore.firestore() }
    private static var isConfigured: Bool { FirebaseApp.app() != nil }

    /// When the pet came home: the "Adopted" step of the application.
    static func adoptedDate(of application: AdoptionApplication) -> Date {
        application.events.last { $0.status == .adopted }?.date ?? application.updatedAt
    }

    /// Creates the journey the first time it's needed (when an adoption is completed,
    /// or when the adopter opens it). Safe to call again: it does nothing if it exists.
    static func ensureJourney(for application: AdoptionApplication, adopterID: String) async {
        guard isConfigured, application.status == .adopted else { return }
        let reference = db.collection("journeys").document(application.id.uuidString)
        if let existing = try? await reference.getDocument(), existing.exists { return }
        reference.setData([
            "adopterID": adopterID,
            "listerID": application.pet.shelterID,
            "listingID": application.pet.id,
            "petName": application.pet.name,
            "petSpecies": application.pet.species,
            "adoptedAt": Timestamp(date: adoptedDate(of: application)),
            "shareHappyTails": true,
            "createdAt": FieldValue.serverTimestamp(),
        ], completion: nil)
    }

    /// Posts a photo and/or a few words to the journey.
    static func post(text: String, photo: Data?, to journey: Journey) async throws {
        guard isConfigured else { throw APIError.notConfigured }
        guard let uid = Auth.auth().currentUser?.uid else { throw APIError.notSignedIn }
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !clean.isEmpty || photo != nil else { throw BackendMessage(text: "Add a photo or a few words first.") }

        var data: [String: Any] = ["authorID": uid, "text": clean, "createdAt": FieldValue.serverTimestamp()]
        if let photo { data["photo"] = photo.base64EncodedString() }
        let reference = db.collection("journeys").document(journey.id).collection("updates").document()
        do {
            try await withNetworkTimeout { try await reference.setData(data) }
        } catch {
            throw backendError(error)
        }
    }

    /// Removes one of my updates (and its Happy tail, if the lister had featured it).
    static func delete(_ update: JourneyUpdate, from journey: Journey, wasFeatured: Bool) {
        guard isConfigured else { return }
        let batch = db.batch()
        batch.deleteDocument(db.collection("journeys").document(journey.id).collection("updates").document(update.id))
        if wasFeatured { batch.deleteDocument(db.collection("happyTails").document(update.id)) }
        batch.commit(completion: nil)
    }

    /// The adopter's switch for "let the lister feature my updates". Turning it off
    /// also takes down anything already featured.
    static func setSharing(_ on: Bool, for journey: Journey, featuredIDs: Set<String>) {
        guard isConfigured else { return }
        let batch = db.batch()
        batch.updateData(["shareHappyTails": on], forDocument: db.collection("journeys").document(journey.id))
        if !on {
            for id in featuredIDs { batch.deleteDocument(db.collection("happyTails").document(id)) }
        }
        batch.commit(completion: nil)
    }

    /// The lister shows an update on their profile.
    static func feature(_ update: JourneyUpdate, in journey: Journey) async throws {
        guard isConfigured else { throw APIError.notConfigured }
        var data: [String: Any] = [
            "applicationID": journey.id,
            "listerID": journey.listerID,
            "adopterID": journey.adopterID,
            "petName": journey.petName,
            "text": update.text,
            "createdAt": Timestamp(date: update.createdAt),
            "featuredAt": FieldValue.serverTimestamp(),
        ]
        // A smaller copy of the photo keeps the profile page light.
        if let base64 = update.photoBase64, let bytes = Data(base64Encoded: base64),
           let small = ImageCompressor.jpeg(from: bytes, maxSide: 500, quality: 0.5) {
            data["photo"] = small.base64EncodedString()
        }
        let reference = db.collection("happyTails").document(update.id)
        do {
            try await withNetworkTimeout { try await reference.setData(data) }
        } catch {
            throw backendError(error)
        }
    }

    /// Takes an update off the lister's profile (the lister or the adopter can do this).
    static func unfeature(updateID: String) {
        guard isConfigured else { return }
        db.collection("happyTails").document(updateID).delete(completion: nil)
    }

    /// The Happy tails shown on a lister's profile, newest first. Empty if the
    /// user isn't signed in (the rules only let signed-in people read them).
    static func happyTails(forLister listerID: String) async -> [HappyTail] {
        guard isConfigured else { return [] }
        let snapshot = try? await db.collection("happyTails")
            .whereField("listerID", isEqualTo: listerID)
            .limit(to: 20)
            .getDocuments()
        let tails: [HappyTail] = (snapshot?.documents ?? []).compactMap {
            HappyTail(id: $0.documentID, data: $0.data(with: .estimate))
        }
        return tails.sorted { $0.createdAt > $1.createdAt }
    }
}

/// Which check-in tasks are ticked. Kept on the phone (UserDefaults): it's a
/// personal checklist, so it doesn't need to be shared.
@MainActor
@Observable
final class JourneyProgressStore {
    static let shared = JourneyProgressStore()

    private(set) var done: Set<String>
    private let key = "journeyTasksDone"

    private init() {
        done = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    private func token(_ applicationID: String, _ milestone: JourneyMilestone, _ task: JourneyTask) -> String {
        "\(applicationID)|\(milestone.rawValue)|\(task.id)"
    }

    func isDone(_ task: JourneyTask, in milestone: JourneyMilestone, for applicationID: String) -> Bool {
        done.contains(token(applicationID, milestone, task))
    }

    func toggle(_ task: JourneyTask, in milestone: JourneyMilestone, for applicationID: String) {
        done.formSymmetricDifference([token(applicationID, milestone, task)])
        UserDefaults.standard.set(Array(done), forKey: key)
    }

    func doneCount(in milestone: JourneyMilestone, for applicationID: String) -> Int {
        milestone.tasks.filter { isDone($0, in: milestone, for: applicationID) }.count
    }

    func isComplete(_ milestone: JourneyMilestone, for applicationID: String) -> Bool {
        doneCount(in: milestone, for: applicationID) == milestone.tasks.count
    }

    /// Check-ins with every task ticked.
    func completedCount(for applicationID: String) -> Int {
        JourneyMilestone.allCases.filter { isComplete($0, for: applicationID) }.count
    }

    /// "Week 1 · 2 of 4 check-ins done": the latest check-in that is due, and overall progress.
    func summary(for applicationID: String, adoptedAt: Date) -> String {
        let current = JourneyMilestone.allCases.last { $0.dueDate(adoptedAt: adoptedAt) <= .now } ?? .day1
        return "\(current.shortTitle) · \(completedCount(for: applicationID)) of \(JourneyMilestone.allCases.count) check-ins done"
    }
}
