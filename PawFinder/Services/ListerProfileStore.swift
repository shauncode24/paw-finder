import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

/// What to do with the profile picture when saving.
enum AvatarChange {
    case keep
    case set(Data)
    case remove
}

/// The signed-in user's own lister profile (`users/{uid}`), kept up to date
/// live. Having a profile with `isLister == true` is what turns on the
/// "list a pet" tools in the Profile tab.
@MainActor
@Observable
final class ListerProfileStore {
    private(set) var profile: ListerProfile?
    private(set) var isLoaded = false

    var isLister: Bool { profile?.isLister == true }

    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var currentUID: String?

    /// Call whenever the signed-in user changes (nil = signed out).
    func start(for uid: String?) {
        guard uid != currentUID else { return }
        listener?.remove()
        listener = nil
        profile = nil
        isLoaded = false
        currentUID = uid

        guard let uid, FirebaseApp.app() != nil else { return }
        listener = Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    guard let self, self.currentUID == uid else { return }
                    if let data = snapshot?.data() {
                        self.profile = ListerProfile(uid: uid, data: data)
                    } else {
                        self.profile = nil
                    }
                    self.isLoaded = true
                }
            }
    }

    /// Saves the profile and marks the user as a lister.
    func save(_ draft: ListerProfile, avatar: AvatarChange = .keep) async throws {
        guard FirebaseApp.app() != nil else { throw APIError.notConfigured }
        guard let uid = Auth.auth().currentUser?.uid else { throw APIError.notSignedIn }

        var profile = draft
        profile.uid = uid
        profile.isLister = true

        var data = profile.data()
        // Approximate position from the city/postcode, for "near me" and the map.
        let place = [profile.city, profile.state, profile.postcode]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        if let coordinate = await ShelterGeocoder.shared.coordinate(forAddress: place) {
            data["latitude"] = coordinate.latitude
            data["longitude"] = coordinate.longitude
        }
        if profile.createdAt == nil { data["createdAt"] = FieldValue.serverTimestamp() }

        switch avatar {
        case .keep: break
        case .set(let bytes):
            let small = ImageCompressor.avatar(from: bytes) ?? bytes
            data["avatar"] = small.base64EncodedString()
        case .remove: data["avatar"] = FieldValue.delete()
        }

        try await Firestore.firestore().collection("users").document(uid).setData(data, merge: true)
        ListerDirectory.shared.forget(uid)
        PhotoLoader.shared.forgetAvatar(of: uid)
    }
}

/// Looks up other people's public profiles (and remembers them for the session).
@MainActor
final class ListerDirectory {
    static let shared = ListerDirectory()
    private var cache: [String: Shelter] = [:]

    private init() {}

    func forget(_ uid: String) {
        cache[uid] = nil
    }

    func shelter(id: String) async throws -> Shelter {
        if let cached = cache[id] { return cached }
        guard FirebaseApp.app() != nil else { throw APIError.notConfigured }
        let document = try await Firestore.firestore().collection("users").document(id).getDocument()
        guard let data = document.data() else { throw APIError.notFound }
        let shelter = ListerProfile(uid: id, data: data).shelter()
        cache[id] = shelter
        return shelter
    }

    /// Several at once (Firestore allows 10 IDs per "in" query).
    func shelters(ids: [String]) async -> [Shelter] {
        guard FirebaseApp.app() != nil else { return [] }
        var found: [Shelter] = ids.compactMap { cache[$0] }
        let missing = ids.filter { cache[$0] == nil }

        var start = 0
        while start < missing.count {
            let chunk = Array(missing[start..<min(start + 10, missing.count)])
            start += 10
            let snapshot = try? await Firestore.firestore().collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            for document in snapshot?.documents ?? [] {
                let shelter = ListerProfile(uid: document.documentID, data: document.data()).shelter()
                cache[document.documentID] = shelter
                found.append(shelter)
            }
        }
        return found
    }
}
