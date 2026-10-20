import UIKit

/// Chats with shelters, saved on the device (Documents/messages.json, photos
/// in Documents/MessageFiles/).
///
/// There's no real shelter on the other end, so a **simulated shelter** reads
/// your message a few seconds later, "types", and replies with an answer
/// based on what you asked. Replies are planned when you send
/// (`pendingReplies`), so they still arrive if you leave the app, with a
/// local notification.
@MainActor
@Observable
final class MessagesStore {
    private(set) var conversations: [Conversation] = []

    private let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("messages.json")

    init() {
        load()
        refresh()
    }

    var unreadCount: Int {
        conversations.filter { !$0.isBlocked }.map(\.unreadCount).reduce(0, +)
    }

    func conversation(_ id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    /// Finds or starts the chat with a shelter (about a pet, if given).
    func startConversation(shelterID: String, shelterName: String, pet: Pet?) -> UUID {
        if let existing = conversations.first(where: { $0.shelterID == shelterID && $0.pet?.id == pet?.id }) {
            return existing.id
        }
        var conversation = Conversation(shelterID: shelterID, shelterName: shelterName, pet: pet)
        conversation.messages.append(Message(
            sender: .system,
            text: "You're chatting with \(shelterName). In this demo, the shelter's replies are simulated.",
            date: .now, sentAt: .now
        ))
        conversations.insert(conversation, at: 0)
        save()
        return conversation.id
    }

    // MARK: - Sending

    /// Sends text and/or a photo. When offline, the message waits in the
    /// outbox and goes out in `flushOutbox()`.
    func send(text: String?, imageData: Data?, in id: UUID, isOnline: Bool) {
        guard let index = index(of: id), !conversations[index].isBlocked else { return }
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageFile = imageData.flatMap(saveImage)
        guard !(trimmed ?? "").isEmpty || imageFile != nil else { return }

        let now = Date.now
        let message = Message(sender: .me, text: trimmed?.isEmpty == false ? trimmed : nil,
                              imageFile: imageFile, date: now, sentAt: isOnline ? now : nil)
        conversations[index].messages.append(message)
        if isOnline { planShelterResponse(to: message, at: index) }
        moveToTop(index)
        save()
    }

    /// Sends everything that was written while offline.
    func flushOutbox() {
        var changed = false
        for index in conversations.indices {
            for messageIndex in conversations[index].messages.indices
            where conversations[index].messages[messageIndex].sender == .me
                && conversations[index].messages[messageIndex].sentAt == nil {
                conversations[index].messages[messageIndex].sentAt = .now
                planShelterResponse(to: conversations[index].messages[messageIndex], at: index)
                changed = true
            }
        }
        if changed { save() }
    }

    // MARK: - Reading, blocking, deleting

    func markRead(_ id: UUID) {
        guard let index = index(of: id), conversations[index].unreadCount > 0 else { return }
        conversations[index].lastReadAt = .now
        save()
    }

    func setBlocked(_ blocked: Bool, _ id: UUID) {
        guard let index = index(of: id) else { return }
        conversations[index].isBlocked = blocked
        if blocked {
            conversations[index].pendingReplies = []
            NotificationManager.shared.cancelMessageNotifications(for: id)
        }
        save()
    }

    func delete(_ id: UUID) {
        guard let conversation = conversation(id) else { return }
        for file in conversation.messages.compactMap(\.imageFile) {
            try? FileManager.default.removeItem(at: imageURL(for: file))
        }
        NotificationManager.shared.cancelMessageNotifications(for: id)
        conversations.removeAll { $0.id == id }
        save()
    }

    /// Saves a report on the device (there's no moderation team to send it to yet).
    func report(_ id: UUID, reason: String, messageID: UUID? = nil) {
        var reports = UserDefaults.standard.stringArray(forKey: "messageReports") ?? []
        reports.append("\(Date.now.ISO8601Format()) | conversation \(id) | message \(messageID?.uuidString ?? "-") | \(reason)")
        UserDefaults.standard.set(reports, forKey: "messageReports")
    }

    func imageURL(for fileName: String) -> URL {
        Self.filesFolder.appendingPathComponent(fileName)
    }

    // MARK: - Simulated shelter

    /// Applies replies whose time has come. Called every second while a chat
    /// is open, and when the app comes to the foreground.
    func refresh(now: Date = .now) {
        var changed = false
        for index in conversations.indices where !conversations[index].isBlocked {
            while let next = conversations[index].pendingReplies.first, next.date <= now {
                conversations[index].pendingReplies.removeFirst()
                conversations[index].messages.append(Message(sender: .shelter, text: next.text,
                                                              date: next.date, sentAt: next.date))
                changed = true
            }
        }
        if changed {
            conversations.sort { ($0.lastMessage?.date ?? $0.createdAt) > ($1.lastMessage?.date ?? $1.createdAt) }
            save()
        }
    }

    /// The shelter reads the message after ~3s and replies ~4s later.
    /// Several quick messages in a row get a single reply.
    private func planShelterResponse(to message: Message, at index: Int) {
        guard let sentAt = message.sentAt,
              let messageIndex = conversations[index].messages.firstIndex(where: { $0.id == message.id }) else { return }
        conversations[index].messages[messageIndex].readAt = sentAt.addingTimeInterval(3)

        let replyDate = sentAt.addingTimeInterval(7)
        let text = Self.replyText(to: message, in: conversations[index])
        conversations[index].pendingReplies.removeAll()   // answer the latest question only
        let reply = ScheduledReply(date: replyDate, text: text)
        conversations[index].pendingReplies.append(reply)

        let conversation = conversations[index]
        Task { await NotificationManager.shared.scheduleMessageReply(reply, in: conversation) }
    }

    private static func replyText(to message: Message, in conversation: Conversation) -> String {
        let petName = conversation.pet?.name ?? "our animals"
        let pet = conversation.pet
        guard let text = message.text?.lowercased() else {
            return "Thanks for the photo! We'll take a look."
        }
        func has(_ words: String...) -> Bool { words.contains { text.contains($0) } }

        if has("visit", "meet", "see ", "come by", "appointment") {
            return "We'd love for you to meet \(petName)! Visits are during opening hours. What day works for you?"
        }
        if has("available", "still there", "adopted yet") {
            return pet?.isAdopted == true
                ? "\(petName) has found a home, but we have lots of other wonderful animals!"
                : "Yes, \(petName) is still available as of today."
        }
        if has("fee", "cost", "price", "how much") {
            return "The adoption fee covers vaccines, spay/neuter, and a microchip. We'll go over the amount when you visit. We never ask for payment before you meet the pet."
        }
        if has("kid", "child", "baby") {
            return switch pet?.goodWithKids {
            case true?: "\(petName) has done really well with kids here."
            case false?: "\(petName) would do best in a home without young kids."
            case nil: "We're not sure yet how \(petName) is with kids. We can arrange a meet-and-greet to see."
            }
        }
        if has("dog") {
            return pet?.goodWithDogs == true ? "\(petName) gets along with other dogs." : "We'd suggest a careful introduction with your dog during a visit."
        }
        if has("cat") {
            return pet?.goodWithCats == true ? "\(petName) has lived with cats." : "We haven't tested \(petName) with cats yet. A slow introduction would be best."
        }
        if has("apply", "application") {
            return "You can apply right in the app: tap \"Apply to adopt\" on \(petName)'s page."
        }
        if has("health", "vaccin", "vet", "medical") {
            return "\(petName) has had a vet check and is up to date on vaccines. We'll share the full records when you visit."
        }
        if has("thank") {
            return "You're welcome! Let us know if you have any other questions."
        }
        return "Thanks for your message! Feel free to ask anything about \(petName): temperament, health, visits, or how adoption works."
    }

    // MARK: - Storage

    private static var filesFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MessageFiles", isDirectory: true)
    }

    private func saveImage(_ data: Data) -> String? {
        guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.7) else { return nil }
        let fileName = "\(UUID().uuidString).jpg"
        do {
            try FileManager.default.createDirectory(at: Self.filesFolder, withIntermediateDirectories: true)
            try jpeg.write(to: imageURL(for: fileName), options: .atomic)
            return fileName
        } catch {
            Log.storage.error("Couldn't save message photo: \(error.localizedDescription)")
            return nil
        }
    }

    private func index(of id: UUID) -> Int? {
        conversations.firstIndex { $0.id == id }
    }

    private func moveToTop(_ index: Int) {
        let conversation = conversations.remove(at: index)
        conversations.insert(conversation, at: 0)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([Conversation].self, from: data) else { return }
        conversations = saved
    }

    private func save() {
        do {
            try JSONEncoder().encode(conversations).write(to: fileURL, options: .atomic)
        } catch {
            Log.storage.error("Couldn't save messages: \(error.localizedDescription)")
        }
    }
}
