import Foundation

/// Saves the first page of each search to disk, so Discover can still show
/// something when the phone is offline. Lives in Caches, so iOS may clear it.
enum PetCache {
    private struct Entry: Codable {
        let savedAt: Date
        let pets: [Pet]
    }

    private static var folder: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PetCache", isDirectory: true)
    }

    static func save(_ pets: [Pet], for query: [String: String]) {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Entry(savedAt: .now, pets: pets))
            try data.write(to: fileURL(for: query), options: .atomic)
        } catch {
            Log.storage.error("Couldn't cache pets: \(error.localizedDescription)")
        }
    }

    static func load(for query: [String: String]) -> (pets: [Pet], savedAt: Date)? {
        guard let data = try? Data(contentsOf: fileURL(for: query)),
              let entry = try? JSONDecoder().decode(Entry.self, from: data) else { return nil }
        return (entry.pets, entry.savedAt)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: folder)
    }

    /// One file per search. The name is a hash of the query, e.g. "a3f9c2e1.json".
    private static func fileURL(for query: [String: String]) -> URL {
        let key = query.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        // FNV-1a: a simple hash that's the same on every launch (unlike `hashValue`).
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return folder.appendingPathComponent(String(hash, radix: 16) + ".json")
    }
}
