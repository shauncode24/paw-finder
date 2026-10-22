import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

/// Reads and writes lister reviews (`reviews/{applicationID}`).
///
/// Writing a review also updates the lister's running total on `users/{listerID}`
/// (`ratingSum`, `ratingCount`) in the same batch, so profiles and pet pages can
/// show "4.8 (12 reviews)" with a single document read. The security rules check
/// that the total only changes together with a real review of an adopted pet.
enum ReviewsService {
    private static var db: Firestore { Firestore.firestore() }

    /// The newest reviews of a lister. No server-side ordering (that would need an
    /// index), so they're sorted here; 100 is plenty for a profile page.
    static func reviews(for listerID: String) async throws -> [Review] {
        guard FirebaseApp.app() != nil else { throw APIError.notConfigured }
        do {
            let snapshot = try await db.collection("reviews")
                .whereField("listerID", isEqualTo: listerID)
                .limit(to: 100)
                .getDocuments()
            return snapshot.documents
                .compactMap { Review(id: $0.documentID, data: $0.data(with: .estimate)) }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            throw backendError(error)
        }
    }

    /// My review for this application, if I've written one.
    static func review(forApplication applicationID: String) async -> Review? {
        guard FirebaseApp.app() != nil else { return nil }
        let document = try? await db.collection("reviews").document(applicationID).getDocument()
        guard let data = document?.data() else { return nil }
        return Review(id: applicationID, data: data)
    }

    /// Saves a new review, or changes my existing one (allowed for a week).
    static func submit(applicationID: String, listerID: String, petName: String, rating: Int, text: String,
                       reviewerName: String, replacing existing: Review?) async throws {
        guard FirebaseApp.app() != nil else { throw APIError.notConfigured }
        guard let uid = Auth.auth().currentUser?.uid else { throw APIError.notSignedIn }
        guard (1...5).contains(rating) else { throw BackendMessage(text: "Choose 1 to 5 stars.") }
        guard uid != listerID else { throw BackendMessage(text: "You can't review yourself.") }

        let cleanText = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Review.maxTextLength))
        let reviewRef = db.collection("reviews").document(applicationID)
        let listerRef = db.collection("users").document(listerID)

        let batch = db.batch()
        if let existing {
            batch.updateData([
                "rating": rating,
                "text": cleanText,
                "updatedAt": FieldValue.serverTimestamp(),
            ], forDocument: reviewRef)
            batch.updateData([
                "ratingSum": FieldValue.increment(Int64(rating - existing.rating)),
                "lastReviewID": applicationID,
            ], forDocument: listerRef)
        } else {
            batch.setData([
                "listerID": listerID,
                "reviewerID": uid,
                "reviewerName": reviewerName,
                "petName": petName,
                "rating": rating,
                "text": cleanText,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ], forDocument: reviewRef)
            batch.updateData([
                "ratingSum": FieldValue.increment(Int64(rating)),
                "ratingCount": FieldValue.increment(Int64(1)),
                "lastReviewID": applicationID,
            ], forDocument: listerRef)
        }

        do {
            try await withNetworkTimeout { try await batch.commit() }
        } catch {
            throw backendError(error)
        }
        await ListerDirectory.shared.forget(listerID)
    }

    /// The lister's reply to a review (an empty reply removes it).
    static func reply(to review: Review, text: String) async throws {
        guard FirebaseApp.app() != nil else { throw APIError.notConfigured }
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Review.maxTextLength))
        let data: [String: Any] = clean.isEmpty
            ? ["reply": FieldValue.delete(), "repliedAt": FieldValue.delete()]
            : ["reply": clean, "repliedAt": FieldValue.serverTimestamp()]
        let reference = db.collection("reviews").document(review.id)
        do {
            try await withNetworkTimeout { try await reference.updateData(data) }
        } catch {
            throw backendError(error)
        }
    }

    /// Reports a review for a moderator to read.
    static func report(_ review: Review, reason: String) {
        guard FirebaseApp.app() != nil else { return }
        var data: [String: Any] = [
            "type": "review",
            "reviewID": review.id,
            "listerID": review.listerID,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let uid = Auth.auth().currentUser?.uid { data["reporterID"] = uid }
        db.collection("reports").addDocument(data: data, completion: nil)
    }
}
