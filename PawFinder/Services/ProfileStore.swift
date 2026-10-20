import UIKit

/// The profile (name, avatar, lifestyle answers) of whoever is using the app:
/// a signed-in account, or "guest". Saved on this device, one profile per user.
///
/// Guest → account: when someone signs in and that account has no profile on
/// this device yet, the guest's profile is copied over, so nothing is lost.
@MainActor
@Observable
final class ProfileStore {
    private(set) var profile = AdopterProfile()
    private(set) var avatar: UIImage?
    private(set) var ownerID = ProfileStore.guestID

    static let guestID = "guest"

    init() {
        load(for: Self.guestID)
    }

    /// Call when the signed-in user changes (nil = signed out, back to guest).
    func switchUser(to userID: String?, suggestedName: String? = nil) {
        let newOwner = userID ?? Self.guestID
        guard newOwner != ownerID else { return }

        let hasOwnProfile = UserDefaults.standard.data(forKey: key(for: newOwner)) != nil
        if newOwner != Self.guestID, !hasOwnProfile, ownerID == Self.guestID {
            // First sign-in on this device: bring the guest's answers and photo along.
            var migrated = profile
            if migrated.displayName.isEmpty { migrated.displayName = suggestedName ?? "" }
            let guestAvatar = try? Data(contentsOf: avatarURL(for: Self.guestID))
            ownerID = newOwner
            profile = migrated
            save()
            if let guestAvatar { try? guestAvatar.write(to: avatarURL(for: newOwner)) }
            avatar = guestAvatar.flatMap(UIImage.init(data:))
        } else {
            load(for: newOwner)
            if profile.displayName.isEmpty, let suggestedName {
                profile.displayName = suggestedName
                save()
            }
        }
    }

    func update(_ change: (inout AdopterProfile) -> Void) {
        change(&profile)
        save()
    }

    /// Shrinks the photo to 512px and saves it as JPEG.
    func setAvatar(_ imageData: Data?) {
        let url = avatarURL(for: ownerID)
        guard let imageData, let image = UIImage(data: imageData) else {
            try? FileManager.default.removeItem(at: url)
            avatar = nil
            return
        }
        let resized = image.resized(maxSide: 512)
        if let jpeg = resized.jpegData(compressionQuality: 0.8) {
            try? jpeg.write(to: url, options: .atomic)
        }
        avatar = resized
    }

    /// Removes a user's profile and photo from this device (account deletion).
    func deleteData(for userID: String) {
        UserDefaults.standard.removeObject(forKey: key(for: userID))
        try? FileManager.default.removeItem(at: avatarURL(for: userID))
        if userID == ownerID {
            profile = AdopterProfile()
            avatar = nil
        }
    }

    // MARK: - Storage

    private func key(for userID: String) -> String { "profile.\(userID)" }

    private func avatarURL(for userID: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatar-\(userID).jpg")
    }

    private func load(for userID: String) {
        ownerID = userID
        if let data = UserDefaults.standard.data(forKey: key(for: userID)),
           let saved = try? JSONDecoder().decode(AdopterProfile.self, from: data) {
            profile = saved
        } else {
            profile = AdopterProfile()
        }
        avatar = (try? Data(contentsOf: avatarURL(for: userID))).flatMap(UIImage.init(data:))
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key(for: ownerID))
        }
    }
}

private extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(size.width, size.height))
        guard scale < 1 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
