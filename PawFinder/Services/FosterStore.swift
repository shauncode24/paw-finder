import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

/// Foster volunteers, for the signed-in user.
///
/// - **As a volunteer:** my own foster profile (`fosters/{uid}`) and the offers I've
///   sent (`fosterOffers`), kept live.
/// - **As a lister:** the offers people sent for my pets, which I accept or decline,
///   and the directory of volunteers nearby.
///
/// Like chats and applications, this works over Firestore listeners (no server);
/// notifications are local, so they appear while the app is open or on iOS's
/// background refresh.
@MainActor
@Observable
final class FosterStore {
    private(set) var profile: FosterProfile?
    private(set) var profileLoaded = false
    private(set) var offers: [FosterOffer] = []
    private(set) var offersLoaded = false
    private(set) var userID: String?

    var isFoster: Bool { profile != nil }

    /// Offers for my pets, newest first.
    var received: [FosterOffer] {
        offers.filter { $0.listerID == userID }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Offers I made, newest first.
    var sent: [FosterOffer] {
        offers.filter { $0.fosterID == userID }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Offers waiting for my answer (shown on the Profile badge).
    var pendingReceivedCount: Int { received.filter { $0.status == .pending }.count }

    @ObservationIgnored private var profileListener: ListenerRegistration?
    @ObservationIgnored private var offersListener: ListenerRegistration?
    @ObservationIgnored private let seenKey = "seenFosterOfferEvents"

    private var isConfigured: Bool { FirebaseApp.app() != nil }
    private var db: Firestore { Firestore.firestore() }

    func offer(forListing listingID: String) -> FosterOffer? {
        sent.first { $0.listingID == listingID }
    }

    // MARK: - Listening

    /// Call whenever the signed-in user changes (nil = signed out).
    func start(for uid: String?) {
        guard uid != userID else { return }
        profileListener?.remove()
        offersListener?.remove()
        profileListener = nil
        offersListener = nil
        profile = nil
        offers = []
        profileLoaded = false
        offersLoaded = false
        userID = uid

        guard isConfigured, let uid else { return }

        profileListener = db.collection("fosters").document(uid).addSnapshotListener { [weak self] snapshot, _ in
            Task { @MainActor in
                guard let self, self.userID == uid else { return }
                if let data = snapshot?.data() {
                    self.profile = FosterProfile(uid: uid, data: data)
                } else {
                    self.profile = nil
                }
                self.profileLoaded = true
            }
        }

        offersListener = db.collection("fosterOffers").whereField("participants", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error { Log.network.error("Foster offers listener: \(error.localizedDescription)") }
                Task { @MainActor in self?.handleOffers(snapshot, uid: uid) }
            }
    }

    private func handleOffers(_ snapshot: QuerySnapshot?, uid: String) {
        guard let snapshot, userID == uid else { return }
        let latest: [FosterOffer] = snapshot.documents.compactMap {
            FosterOffer(id: $0.documentID, data: $0.data(with: .estimate))
        }
        // The first batch only seeds what we've already told the user about.
        notifyAboutNew(latest, me: uid, announce: offersLoaded)
        offers = latest
        offersLoaded = true
    }

    // MARK: - Foster profile

    func saveProfile(_ draft: FosterProfile) async throws {
        guard isConfigured else { throw APIError.notConfigured }
        guard let uid = Auth.auth().currentUser?.uid else { throw APIError.notSignedIn }
        if let problem = draft.problems.first { throw BackendMessage(text: problem) }

        var data = draft.data()
        // Approximate position from the city/postcode, for "near me". Never a street address.
        let place = [draft.city, draft.state, draft.postcode]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        if let coordinate = await ShelterGeocoder.shared.coordinate(forAddress: place) {
            data["latitude"] = coordinate.latitude
            data["longitude"] = coordinate.longitude
        }
        let reference = db.collection("fosters").document(uid)
        do {
            try await withNetworkTimeout { try await reference.setData(data, merge: true) }
        } catch {
            throw backendError(error)
        }
    }

    /// Pause or resume showing up in listers' directory.
    func setAvailable(_ available: Bool) {
        guard isConfigured, let uid = userID else { return }
        db.collection("fosters").document(uid).updateData(["isAvailable": available], completion: nil)
    }

    func removeProfile() async {
        guard isConfigured, let uid = userID else { return }
        try? await db.collection("fosters").document(uid).delete()
    }

    // MARK: - Offers (volunteer)

    func sendOffer(for pet: Pet, listerName: String?, message: String, duration: FosterDuration) async throws {
        guard isConfigured else { throw APIError.notConfigured }
        guard let uid = userID else { throw APIError.notSignedIn }
        guard let profile else { throw BackendMessage(text: "Set up your foster profile first.") }
        guard pet.shelterID != uid else { throw BackendMessage(text: "This is your own listing.") }
        guard pet.needsFoster else { throw BackendMessage(text: "\(pet.name) doesn't need a foster right now.") }
        if offer(forListing: pet.id) != nil {
            throw BackendMessage(text: "You've already sent an offer for \(pet.name). Find it under Profile › Foster offers.")
        }

        let id = FosterOffer.makeID(listingID: pet.id, fosterID: uid)
        let data: [String: Any] = [
            "listingID": pet.id,
            "listingName": pet.name,
            "listingSpecies": pet.species,
            "listerID": pet.shelterID,
            "listerName": listerName ?? pet.listedBy ?? "the lister",
            "fosterID": uid,
            "fosterName": profile.publicName,
            "participants": [pet.shelterID, uid],
            "message": String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)),
            "duration": duration.rawValue,
            "status": FosterOfferStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        let reference = db.collection("fosterOffers").document(id)
        do {
            try await withNetworkTimeout { try await reference.setData(data) }
        } catch {
            throw backendError(error)
        }
    }

    func withdraw(_ offer: FosterOffer) {
        guard isConfigured, offer.fosterID == userID, offer.status == .pending else { return }
        db.collection("fosterOffers").document(offer.id).updateData([
            "status": FosterOfferStatus.withdrawn.rawValue,
            "updatedAt": FieldValue.serverTimestamp(),
        ], completion: nil)
    }

    // MARK: - Offers (lister)

    /// Accepts or declines an offer. Accepting also records on the listing who is
    /// fostering (their public name only) and stops showing "Needs a foster".
    func respond(to offer: FosterOffer, accept: Bool) async throws {
        guard isConfigured else { throw APIError.notConfigured }
        guard offer.listerID == userID, offer.status == .pending else { return }

        let batch = db.batch()
        batch.updateData([
            "status": (accept ? FosterOfferStatus.accepted : FosterOfferStatus.declined).rawValue,
            "updatedAt": FieldValue.serverTimestamp(),
        ], forDocument: db.collection("fosterOffers").document(offer.id))
        if accept {
            batch.updateData([
                "fosterNeeded": false,
                "fosterByID": offer.fosterID,
                "fosterByName": offer.fosterName,
                "updatedAt": FieldValue.serverTimestamp(),
            ], forDocument: db.collection("listings").document(offer.listingID))
        }
        do {
            try await withNetworkTimeout { try await batch.commit() }
        } catch {
            throw backendError(error)
        }
    }

    /// The foster stay is over: the listing no longer says "In foster care with…".
    func endFosterCare(listingID: String) {
        guard isConfigured else { return }
        db.collection("listings").document(listingID).updateData([
            "fosterByID": FieldValue.delete(),
            "fosterByName": FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp(),
        ], completion: nil)
    }

    // MARK: - Directory (listers only)

    /// Volunteers who are available. The rules only let listers read these.
    func loadDirectory() async throws -> [FosterProfile] {
        guard isConfigured else { throw APIError.notConfigured }
        do {
            let snapshot = try await db.collection("fosters")
                .whereField("isAvailable", isEqualTo: true)
                .limit(to: 300)
                .getDocuments()
            return snapshot.documents
                .map { FosterProfile(uid: $0.documentID, data: $0.data(with: .estimate)) }
                .filter { $0.uid != userID }
        } catch {
            throw backendError(error)
        }
    }

    // MARK: - Notifications

    /// Tells the lister about new offers and the volunteer about answers, once each.
    private func notifyAboutNew(_ latest: [FosterOffer], me: String, announce: Bool) {
        var seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        for offer in latest {
            let token = "\(offer.id)|\(offer.status.rawValue)"
            let isForMe = (offer.listerID == me && offer.status == .pending)
                || (offer.fosterID == me && (offer.status == .accepted || offer.status == .declined))
            guard isForMe, !seen.contains(token) else { continue }
            seen.insert(token)
            guard announce else { continue }
            Task {
                if offer.listerID == me {
                    await NotificationManager.shared.notifyNewFosterOffer(
                        petName: offer.listingName, from: offer.fosterName)
                } else {
                    await NotificationManager.shared.notifyFosterOfferAnswer(
                        petName: offer.listingName, accepted: offer.status == .accepted)
                }
            }
        }
        UserDefaults.standard.set(Array(seen), forKey: seenKey)
    }

    /// Run by iOS's background refresh: a look for offers and answers that arrived while the app was closed.
    func backgroundCheck() async {
        guard isConfigured, let uid = Auth.auth().currentUser?.uid else { return }
        let snapshot = try? await db.collection("fosterOffers").whereField("participants", arrayContains: uid).getDocuments()
        let latest: [FosterOffer] = (snapshot?.documents ?? []).compactMap {
            FosterOffer(id: $0.documentID, data: $0.data(with: .estimate))
        }
        notifyAboutNew(latest, me: uid, announce: true)
    }
}
