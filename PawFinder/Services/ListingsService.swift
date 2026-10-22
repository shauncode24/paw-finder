import CoreLocation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

/// A plain-text error that's safe to show.
struct BackendMessage: LocalizedError {
    let text: String
    var errorDescription: String? { text }
}

/// Turns Firestore's numeric error codes into the app's friendly errors.
func backendError(_ error: Error) -> Error {
    let ns = error as NSError
    guard ns.domain.contains("Firestore") else { return error }
    switch ns.code {
    case 5: return APIError.notFound
    case 7, 16: return APIError.unauthorized      // permission denied / not signed in
    case 4, 14: return APIError.offline           // timed out / service unavailable
    case 8: return APIError.rateLimited           // free-plan quota used up
    default: return error
    }
}

/// Runs a Firestore write that normally waits for the server, but gives up after
/// `seconds`, so an offline phone gets a clear "you're offline" instead of
/// spinning forever. (Writes the app doesn't wait for, like chat messages, are
/// simply queued by Firestore and sent later.)
func withNetworkTimeout(seconds: Double = 15, _ work: @escaping () async throws -> Void) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw APIError.offline
        }
        _ = try await group.next()
        group.cancelAll()
    }
}

/// All adoption listings, live.
///
/// One Firestore listener keeps `listings` up to date for everyone: when any
/// lister posts, edits, or marks a pet adopted, every open app updates within
/// a second or two. Searching and filtering then happens on the phone, which
/// keeps the free Firestore plan far below its read limits (and avoids needing
/// database indexes).
@MainActor
@Observable
final class ListingsService {
    /// Every available or pending listing, newest first.
    private(set) var listings: [Pet] = []
    /// The signed-in user's own listings (including adopted ones), newest first.
    private(set) var myListings: [Pet] = []
    /// True once the first batch has arrived (from the server, or from the phone's saved copy).
    private(set) var isReady = false
    private(set) var loadError: String?
    /// Goes up every time the feed changes, so screens can refresh.
    private(set) var revision = 0

    let isConfigured: Bool

    @ObservationIgnored private var feedListener: ListenerRegistration?
    @ObservationIgnored private var mineListener: ListenerRegistration?
    @ObservationIgnored private var mineUID: String?
    @ObservationIgnored private var byID: [String: Pet] = [:]

    /// Create this after `FirebaseApp.configure()`.
    init() {
        isConfigured = FirebaseApp.app() != nil
        if isConfigured { startFeed() }
    }

    // MARK: - Live feed

    private func startFeed() {
        // Only "isActive" listings (available or pending) are in the feed. The
        // limit keeps a runaway database from downloading forever.
        feedListener = Firestore.firestore().collection("listings")
            .whereField("isActive", isEqualTo: true)
            .limit(to: 500)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in self?.handleFeed(snapshot, error) }
            }
    }

    private func handleFeed(_ snapshot: QuerySnapshot?, _ error: Error?) {
        if let error {
            loadError = Self.explain(error)
            Log.network.error("Listings feed error: \(error.localizedDescription)")
            return
        }
        guard let snapshot else { return }
        for change in snapshot.documentChanges {
            let id = change.document.documentID
            switch change.type {
            case .added, .modified:
                cacheThumbnail(from: change.document.data(), id: id)
                if let pet = ListingMapper.pet(id: id, data: change.document.data()) {
                    byID[id] = pet
                }
            case .removed:
                byID[id] = nil
            }
        }
        listings = byID.values.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        loadError = nil
        isReady = true
        revision += 1
    }

    private func cacheThumbnail(from data: [String: Any], id: String) {
        guard let text = data["thumbnail"] as? String else { return }
        PhotoLoader.shared.setThumbnail(Data(base64Encoded: text), for: id)
    }

    private static func explain(_ error: Error) -> String {
        let translated = backendError(error)
        if case APIError.unauthorized = translated {
            return "PawFinder can't read the listings yet. Publish the Firestore rules from docs/Listers-and-Messaging.md."
        }
        return translated.localizedDescription
    }

    /// Waits for the first batch of listings, so a search never shows a false "no pets".
    func waitUntilReady(timeout: TimeInterval = 10) async throws {
        guard isConfigured else { throw APIError.notConfigured }
        let deadline = Date.now.addingTimeInterval(timeout)
        while !isReady {
            if let loadError { throw BackendMessage(text: loadError) }
            if Date.now > deadline { throw APIError.offline }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: - Searching (on the phone)

    /// Filters, sorts, and (when `origin` is given) measures distances.
    func search(filters: PetFilters, origin: CLLocationCoordinate2D?) -> [Pet] {
        var results = listings.filter { filters.matches($0) }

        if let origin {
            let here = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            let maxMiles = Double(filters.distance)
            results = results.compactMap { pet in
                guard let latitude = pet.latitude, let longitude = pet.longitude else { return nil }
                let miles = CLLocation(latitude: latitude, longitude: longitude).distance(from: here) / 1609.34
                guard miles <= maxMiles else { return nil }
                var copy = pet
                copy.distance = miles
                return copy
            }
        }

        switch filters.sort {
        case .newest:
            results.sort { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        case .longestWaiting:
            results.sort { ($0.publishedAt ?? .distantFuture) < ($1.publishedAt ?? .distantFuture) }
        case .nearest:
            if origin != nil {
                results.sort { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
            }
        case .random:
            results.shuffle()
        }
        return results
    }

    /// The people with at least one live listing (for the map).
    func listerIDs() -> [String] {
        Array(Set(listings.map(\.shelterID)))
    }

    func listing(id: String) -> Pet? { byID[id] }

    /// One listing, including adopted ones (which aren't in the live feed).
    func fetchListing(id: String) async throws -> Pet {
        guard isConfigured else { throw APIError.notConfigured }
        if let live = byID[id] { return live }
        do {
            let document = try await Firestore.firestore().collection("listings").document(id).getDocument()
            guard let data = document.data(), let pet = ListingMapper.pet(id: id, data: data) else {
                throw APIError.notFound
            }
            cacheThumbnail(from: data, id: id)
            return pet
        } catch let error as APIError {
            throw error
        } catch {
            throw backendError(error)
        }
    }

    // MARK: - The signed-in user's listings

    /// Call whenever the signed-in user changes (nil = signed out).
    func startMine(for uid: String?) {
        guard uid != mineUID else { return }
        mineListener?.remove()
        mineListener = nil
        myListings = []
        mineUID = uid
        guard isConfigured, let uid else { return }

        mineListener = Firestore.firestore().collection("listings")
            .whereField("ownerID", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in self?.handleMine(snapshot, uid: uid) }
            }
    }

    private func handleMine(_ snapshot: QuerySnapshot?, uid: String) {
        guard let snapshot, mineUID == uid else { return }
        var pets: [Pet] = []
        for document in snapshot.documents {
            cacheThumbnail(from: document.data(), id: document.documentID)
            if let pet = ListingMapper.pet(id: document.documentID, data: document.data()) {
                pets.append(pet)
            }
        }
        myListings = pets.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    }

    // MARK: - Creating and editing

    /// Opens a saved listing for editing, including its photos.
    func loadDraft(id: String) async throws -> ListingDraft {
        guard isConfigured else { throw APIError.notConfigured }
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("listings").document(id).getDocument()
            guard let data = document.data() else { throw APIError.notFound }
            var draft = ListingMapper.draft(id: id, data: data)
            for index in 0..<draft.originalPhotoCount {
                if let url = PhotoURL.photo(index, of: id), let bytes = await PhotoLoader.shared.data(for: url) {
                    draft.photos.append(bytes)
                }
            }
            return draft
        } catch let error as APIError {
            throw error
        } catch {
            throw backendError(error)
        }
    }

    /// Publishes a new listing or saves changes to an existing one.
    /// - Returns: the listing's ID.
    @discardableResult
    func publish(_ draft: ListingDraft, owner: ListerProfile) async throws -> String {
        guard isConfigured else { throw APIError.notConfigured }
        guard let uid = Auth.auth().currentUser?.uid else { throw APIError.notSignedIn }
        if let problem = draft.problems.first { throw BackendMessage(text: problem) }

        let db = Firestore.firestore()
        let reference: DocumentReference
        if let existingID = draft.id {
            reference = db.collection("listings").document(existingID)
        } else {
            reference = db.collection("listings").document()
        }

        // Each photo has to fit comfortably inside one document (1 MB limit).
        var photos: [Data] = []
        for bytes in draft.photos.prefix(ListingDraft.maxPhotos) {
            photos.append(bytes.count > 600_000 ? (ImageCompressor.fullSize(from: bytes) ?? bytes) : bytes)
        }
        let thumbnail = ImageCompressor.thumbnail(from: photos[0])?.base64EncodedString()

        // Approximate position, from the city/postcode, for "near me" searches.
        let place = [draft.city, draft.state, draft.postcode]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        let coordinate = await ShelterGeocoder.shared.coordinate(forAddress: place)

        let data = ListingMapper.data(
            from: draft, ownerID: uid, ownerName: owner.publicName, photoCount: photos.count,
            thumbnail: thumbnail, latitude: coordinate?.latitude, longitude: coordinate?.longitude
        )

        let batch = db.batch()
        batch.setData(data, forDocument: reference)
        for (index, bytes) in photos.enumerated() {
            batch.setData(["data": bytes.base64EncodedString(), "order": index],
                          forDocument: reference.collection("photos").document(String(index)))
        }
        // The listing used to have more photos: remove the extras.
        if draft.originalPhotoCount > photos.count {
            for index in photos.count..<draft.originalPhotoCount {
                batch.deleteDocument(reference.collection("photos").document(String(index)))
            }
        }

        do {
            try await withNetworkTimeout { try await batch.commit() }
        } catch {
            throw backendError(error)
        }
        PhotoLoader.shared.forgetPhotos(of: reference.documentID)
        return reference.documentID
    }

    func setStatus(_ status: ListingStatus, for listingID: String) async throws {
        guard isConfigured else { throw APIError.notConfigured }
        do {
            try await Firestore.firestore().collection("listings").document(listingID).updateData([
                "status": status.rawValue,
                "isActive": status != .adopted,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
        } catch {
            throw backendError(error)
        }
    }

    func delete(listingID: String, photoCount: Int) async throws {
        guard isConfigured else { throw APIError.notConfigured }
        let reference = Firestore.firestore().collection("listings").document(listingID)
        let batch = Firestore.firestore().batch()
        for index in 0..<max(photoCount, 0) {
            batch.deleteDocument(reference.collection("photos").document(String(index)))
        }
        batch.deleteDocument(reference)
        do {
            try await withNetworkTimeout { try await batch.commit() }
        } catch {
            throw backendError(error)
        }
    }

    /// Removes everything the signed-in user has listed (used when deleting an account).
    func deleteAllMine() async {
        guard isConfigured else { return }
        for pet in myListings {
            try? await delete(listingID: pet.id, photoCount: pet.photoURLs.count)
        }
    }

    // MARK: - Reports

    /// Tells the (future) moderators about a problem listing. Anyone can send one.
    func report(listingID: String, reason: String, details: String) async {
        guard isConfigured else { return }
        var data: [String: Any] = [
            "type": "listing",
            "listingID": listingID,
            "reason": reason,
            "details": details,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let uid = Auth.auth().currentUser?.uid { data["reporterID"] = uid }
        try? await Firestore.firestore().collection("reports").addDocument(data: data)
    }
}
