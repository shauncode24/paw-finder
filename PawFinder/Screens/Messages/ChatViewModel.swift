import FirebaseCore
import FirebaseFirestore
import Foundation

/// The live messages of one open chat. A Firestore listener keeps `messages`
/// current: new messages from the other person appear as they're sent, and
/// your own messages show as "pending" until the server has them.
@MainActor
@Observable
final class ChatViewModel {
    let conversationID: String
    private(set) var messages: [ChatMessage] = []
    private(set) var hasEarlier = false
    private(set) var isLoaded = false

    @ObservationIgnored private var limit = 40
    @ObservationIgnored private var listener: ListenerRegistration?

    private static let pageSize = 40

    init(conversationID: String) {
        self.conversationID = conversationID
    }

    func start() {
        guard listener == nil else { return }
        attach()
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    /// Shows 40 more older messages.
    func loadEarlier() {
        limit += Self.pageSize
        attach()
    }

    private func attach() {
        listener?.remove()
        guard FirebaseApp.app() != nil else { return }
        listener = Firestore.firestore()
            .collection("conversations").document(conversationID).collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                if let error { Log.network.error("Messages listener: \(error.localizedDescription)") }
                Task { @MainActor in self?.handle(snapshot) }
            }
    }

    private func handle(_ snapshot: QuerySnapshot?) {
        guard let snapshot else { return }
        hasEarlier = snapshot.documents.count >= limit
        // The query is newest-first (so "limit" keeps the latest ones); show oldest-first.
        messages = snapshot.documents.reversed().compactMap { document in
            ChatMessage(id: document.documentID,
                        data: document.data(with: .estimate),
                        isPending: document.metadata.hasPendingWrites)
        }
        isLoaded = true
    }
}
