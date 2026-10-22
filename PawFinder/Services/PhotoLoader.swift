import FirebaseCore
import FirebaseFirestore
import SwiftUI

// MARK: - Photo addresses

/// Photos live inside Firestore documents (no Firebase Storage, so no paid plan).
/// The rest of the app doesn't care: it just holds URLs. Listing photos use a
/// private "pfphoto" scheme that `PhotoLoader` knows how to resolve:
///
///     pfphoto:///thumb/<listingID>            the small card photo
///     pfphoto:///photo/<listingID>/<index>    a full-size photo
///     pfphoto:///avatar/<userID>              a lister's profile picture
enum PhotoURL {
    static func thumbnail(of listingID: String) -> URL? { URL(string: "pfphoto:///thumb/\(listingID)") }
    static func photo(_ index: Int, of listingID: String) -> URL? { URL(string: "pfphoto:///photo/\(listingID)/\(index)") }
    static func avatar(of userID: String) -> URL? { URL(string: "pfphoto:///avatar/\(userID)") }
}

enum PhotoRef {
    case thumbnail(listingID: String)
    case photo(listingID: String, index: Int)
    case avatar(userID: String)

    init?(url: URL) {
        guard url.scheme == "pfphoto" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch (parts.first, parts.count) {
        case ("thumb", 2): self = .thumbnail(listingID: parts[1])
        case ("photo", 3):
            guard let index = Int(parts[2]) else { return nil }
            self = .photo(listingID: parts[1], index: index)
        case ("avatar", 2): self = .avatar(userID: parts[1])
        default: return nil
        }
    }
}

// MARK: - Loading and caching

/// Loads photos for `RemoteImage`: from memory, from the live listings feed
/// (thumbnails), or from Firestore (full-size photos and avatars). Firestore
/// keeps its own offline copy, so photos you've seen also work offline.
@MainActor
final class PhotoLoader {
    static let shared = PhotoLoader()

    private let images = NSCache<NSString, UIImage>()
    /// Listing ID → thumbnail bytes, filled in by `ListingsService` as listings arrive.
    private var thumbnails: [String: Data] = [:]
    private var inFlight: [String: Task<Data?, Never>] = [:]

    private init() {
        images.countLimit = 300
    }

    /// Called by the live feed so card photos show immediately, without extra reads.
    func setThumbnail(_ data: Data?, for listingID: String) {
        thumbnails[listingID] = data
        images.removeObject(forKey: "thumb/\(listingID)" as NSString)
    }

    /// After a lister changes their picture, drop the old one.
    func forgetAvatar(of userID: String) {
        images.removeObject(forKey: "avatar/\(userID)" as NSString)
    }

    /// After a listing's photos are edited, drop the old full-size ones.
    func forgetPhotos(of listingID: String) {
        for index in 0..<ListingDraft.maxPhotos {
            images.removeObject(forKey: "photo/\(listingID)/\(index)" as NSString)
        }
    }

    func cachedImage(for url: URL) -> UIImage? {
        if let image = images.object(forKey: key(for: url)) { return image }
        // Thumbnails are already in memory as bytes; turn them into an image right away.
        if case .thumbnail(let id)? = PhotoRef(url: url), let data = thumbnails[id], let image = UIImage(data: data) {
            images.setObject(image, forKey: key(for: url))
            return image
        }
        return nil
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cachedImage(for: url) { return cached }
        guard let data = await data(for: url), let image = UIImage(data: data) else { return nil }
        images.setObject(image, forKey: key(for: url))
        return image
    }

    /// The raw JPEG bytes (used when saving a favorite's photo, or editing a listing).
    func data(for url: URL) async -> Data? {
        let id = key(for: url) as String
        if let running = inFlight[id] { return await running.value }
        let task = Task { await self.fetch(url) }
        inFlight[id] = task
        let result = await task.value
        inFlight[id] = nil
        return result
    }

    // MARK: Private

    private func key(for url: URL) -> NSString {
        guard let ref = PhotoRef(url: url) else { return url.absoluteString as NSString }
        switch ref {
        case .thumbnail(let id): return "thumb/\(id)" as NSString
        case .photo(let id, let index): return "photo/\(id)/\(index)" as NSString
        case .avatar(let id): return "avatar/\(id)" as NSString
        }
    }

    private func fetch(_ url: URL) async -> Data? {
        guard let ref = PhotoRef(url: url) else { return await webData(url) }
        guard FirebaseApp.app() != nil else { return nil }
        let db = Firestore.firestore()
        do {
            switch ref {
            case .thumbnail(let id):
                if let data = thumbnails[id] { return data }
                let document = try await db.collection("listings").document(id).getDocument()
                guard let text = document.data()?["thumbnail"] as? String else { return nil }
                return Data(base64Encoded: text)
            case .photo(let id, let index):
                let document = try await db.collection("listings").document(id)
                    .collection("photos").document(String(index)).getDocument()
                guard let text = document.data()?["data"] as? String else { return nil }
                return Data(base64Encoded: text)
            case .avatar(let id):
                let document = try await db.collection("users").document(id).getDocument()
                guard let text = document.data()?["avatar"] as? String else { return nil }
                return Data(base64Encoded: text)
            }
        } catch {
            Log.network.error("Couldn't load a photo: \(error.localizedDescription)")
            return nil
        }
    }

    private func webData(_ url: URL) async -> Data? {
        try? await URLSession.shared.data(from: url).0
    }
}

// MARK: - Resizing photos before upload

enum ImageCompressor {
    /// Shrinks a photo so it fits inside a Firestore document (1 MB limit,
    /// and base64 adds a third). Returns JPEG bytes.
    static func jpeg(from data: Data, maxSide: CGFloat, quality: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return jpeg(from: image, maxSide: maxSide, quality: quality)
    }

    static func jpeg(from image: UIImage, maxSide: CGFloat, quality: CGFloat) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1   // we want exact pixel sizes, not screen-scaled ones
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    /// Card photo, about 10 KB.
    static func thumbnail(from data: Data) -> Data? { jpeg(from: data, maxSide: 280, quality: 0.5) }
    /// Detail-screen photo, about 80–150 KB.
    static func fullSize(from data: Data) -> Data? { jpeg(from: data, maxSide: 900, quality: 0.6) }
    /// Profile picture, a few KB.
    static func avatar(from data: Data) -> Data? { jpeg(from: data, maxSide: 160, quality: 0.6) }
    /// Photo sent in a chat.
    static func chatPhoto(from data: Data) -> Data? { jpeg(from: data, maxSide: 800, quality: 0.55) }
}

// MARK: - Image view

enum RemoteImagePhase {
    case empty            // still loading
    case success(Image)
    case failure          // no photo, or it couldn't be loaded
}

/// Like `AsyncImage`, but understands `pfphoto:` URLs and keeps a memory cache.
struct RemoteImage<Content: View>: View {
    let url: URL?
    @ViewBuilder var content: (RemoteImagePhase) -> Content
    @State private var phase: RemoteImagePhase = .empty

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            phase = .failure
            return
        }
        if let cached = PhotoLoader.shared.cachedImage(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }
        phase = .empty
        if let image = await PhotoLoader.shared.image(for: url) {
            phase = .success(Image(uiImage: image))
        } else {
            phase = .failure
        }
    }
}
