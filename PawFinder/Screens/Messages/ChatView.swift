import MapKit
import PhotosUI
import SwiftUI

/// One chat between an adopter and a lister: live messages grouped by day,
/// "Sent / Read" receipts, "typing…", photos, and report/block. Messages
/// written offline wait ("Waiting to send") and go out when you reconnect.
struct ChatView: View {
    let conversationID: String

    @Environment(MessagesStore.self) private var store
    @Environment(NetworkMonitor.self) private var network
    @Environment(ListingsService.self) private var listings
    @State private var viewModel: ChatViewModel

    @State private var draft = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var moderationWarning: String?
    @State private var blockedMessage: String?
    @State private var showReport = false
    @State private var reportedMessageID: String?
    @State private var confirmBlock = false
    @State private var showMeetupPicker = false
    /// Set when answering someone's proposal with a different place or time.
    @State private var counteringMessageID: String?
    @State private var fullScreenImage: ViewerImage?
    @State private var lastTypingSent = Date.distantPast
    @State private var typingTask: Task<Void, Never>?
    @FocusState private var composerFocused: Bool

    init(conversationID: String) {
        self.conversationID = conversationID
        _viewModel = State(initialValue: ChatViewModel(conversationID: conversationID))
    }

    private var me: String { store.userID ?? "" }

    var body: some View {
        Group {
            if let conversation = store.conversation(conversationID) {
                // Re-evaluated every second, for "typing…" and read receipts.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    content(conversation, now: context.date)
                }
            } else if store.isLoaded {
                EmptyStateView(icon: "bubble.left", title: "Chat not found", message: "It may have been removed.")
            } else {
                LoadingView(message: "Loading chat...")
            }
        }
        .background(Color.pfBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            NotificationManager.shared.openConversationID = conversationID
            viewModel.start()
            store.markRead(conversationID)
        }
        .onDisappear {
            viewModel.stop()
            typingTask?.cancel()
            store.setTyping(false, in: conversationID)
            if NotificationManager.shared.openConversationID == conversationID {
                NotificationManager.shared.openConversationID = nil
            }
        }
        // Anything new on screen counts as read.
        .onChange(of: viewModel.messages.count) { store.markRead(conversationID) }
        .onChange(of: draft) { _, text in draftChanged(text) }
        .onChange(of: photoItem) { _, item in sendPhoto(item) }
        .alert("Before you send", isPresented: Binding(get: { moderationWarning != nil },
                                                       set: { if !$0 { moderationWarning = nil } })) {
            Button("Edit message", role: .cancel) {}
            Button("Send anyway") { sendDraft(skipChecks: true) }
        } message: {
            Text(moderationWarning ?? "")
        }
        .alert("Can't send", isPresented: Binding(get: { blockedMessage != nil },
                                                  set: { if !$0 { blockedMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(blockedMessage ?? "")
        }
        .confirmationDialog("Report", isPresented: $showReport, titleVisibility: .visible) {
            ForEach(["Spam or scam", "Rude or abusive", "Asked for payment up front", "Something else"], id: \.self) { reason in
                Button(reason) {
                    store.report(conversationID, reason: reason, messageID: reportedMessageID)
                    reportedMessageID = nil
                }
            }
        } message: {
            Text("Thanks for helping keep PawFinder safe. Reports are saved for review.")
        }
        .confirmationDialog("Block this person?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) { store.setBlocked(true, conversationID) }
        } message: {
            Text("Neither of you can send messages in this chat until you unblock. You can unblock any time.")
        }
        .fullScreenCover(item: $fullScreenImage) { image in
            ImageViewer(image: image.image)
        }
        .sheet(isPresented: $showMeetupPicker, onDismiss: { counteringMessageID = nil }) {
            PlacePickerView(startCoordinate: petCoordinate, me: me) { meetup in
                store.proposeMeetup(meetup, replacing: counteringMessageID, in: conversationID)
            }
        }
    }

    /// Where the pet is, so the place picker opens in the right area.
    private var petCoordinate: CLLocationCoordinate2D? {
        guard let conversation = store.conversation(conversationID),
              let pet = listings.listings.first(where: { $0.id == conversation.listingID }),
              let latitude = pet.latitude, let longitude = pet.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func handleMeetup(_ action: MeetupAction, on message: ChatMessage) {
        guard let meetup = message.meetup else { return }
        switch action {
        case .accept:
            store.respondToMeetup(messageID: message.id, meetup: meetup, accept: true, in: conversationID)
        case .decline, .cancel:
            store.respondToMeetup(messageID: message.id, meetup: meetup, accept: false, in: conversationID)
        case .counter:
            counteringMessageID = message.id
            showMeetupPicker = true
        }
    }

    // MARK: - Layout

    private func content(_ conversation: Conversation, now: Date) -> some View {
        VStack(spacing: 0) {
            if !network.isOnline {
                Label("You're offline. Messages will send when you reconnect.", systemImage: "wifi.slash")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.sm)
                    .background(Color.pfBrandDeep)
            }
            petHeader(conversation)
            messageList(conversation, now: now)
            if conversation.isBlocked {
                blockedBar(conversation)
            } else {
                composer
            }
        }
        .navigationTitle(conversation.otherName(for: me))
        .toolbar { toolbarMenu(conversation) }
    }

    /// A slim "About Luna" bar that opens the pet.
    private func petHeader(_ conversation: Conversation) -> some View {
        NavigationLink(value: Route.petID(conversation.listingID)) {
            HStack(spacing: Spacing.sm) {
                Color.clear
                    .frame(width: 36, height: 36)
                    .overlay { PetPhoto(url: PhotoURL.thumbnail(of: conversation.listingID), species: conversation.listingSpecies) }
                    .clipShape(Circle())
                Text("About \(conversation.listingName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.pfTextPrimary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.pfTextSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(.bar)
        }
        .buttonStyle(.plain)
    }

    private func messageList(_ conversation: Conversation, now: Date) -> some View {
        let messages = viewModel.messages
        let other = conversation.otherID(for: me)
        let lastMineID = messages.last { $0.senderID == me }?.id
        let otherTyping = isOtherTyping(conversation, other: other, now: now)

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    if viewModel.hasEarlier {
                        Button("Load earlier messages") { viewModel.loadEarlier() }
                            .font(.subheadline)
                            .padding(.vertical, Spacing.sm)
                    }
                    if messages.isEmpty, viewModel.isLoaded {
                        Text("Say hello! Ask about \(conversation.listingName)'s personality, health, or how adoption works.")
                            .font(.subheadline)
                            .foregroundStyle(Color.pfTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(Spacing.xl)
                    }
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        if index == 0 || !Calendar.current.isDate(message.createdAt, inSameDayAs: messages[index - 1].createdAt) {
                            Text(message.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.pfCaption)
                                .foregroundStyle(Color.pfTextSecondary)
                                .padding(.top, Spacing.sm)
                        }
                        MessageBubble(
                            message: message,
                            isMine: message.senderID == me,
                            proposerName: conversation.otherName(for: me),
                            onMeetupAction: { handleMeetup($0, on: message) },
                            statusText: message.id == lastMineID ? status(of: message, in: conversation, other: other) : nil,
                            onTapImage: { fullScreenImage = ViewerImage(id: message.id, image: $0) },
                            onReport: {
                                reportedMessageID = message.id
                                showReport = true
                            }
                        )
                        .id(message.id)
                    }
                    if otherTyping {
                        TypingIndicator(name: conversation.otherName(for: me))
                            .id("typing")
                    }
                }
                .padding(Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: messages.last?.id) {
                if let last = messages.last?.id {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
            .onChange(of: otherTyping) {
                if otherTyping { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Send a photo")

            Button {
                counteringMessageID = nil
                showMeetupPicker = true
            } label: {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Suggest a meet-up")

            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($composerFocused)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.large))
                .overlay(RoundedRectangle(cornerRadius: Radius.large).stroke(Color.pfBorder))

            Button {
                sendDraft()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .frame(width: 44, height: 44)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.bar)
    }

    private func blockedBar(_ conversation: Conversation) -> some View {
        HStack {
            if conversation.isBlockedByMe(me) {
                Text("You blocked this person.")
                    .foregroundStyle(Color.pfTextSecondary)
                Spacer()
                Button("Unblock") { store.setBlocked(false, conversationID) }
            } else {
                Text("You can't reply to this chat.")
                    .foregroundStyle(Color.pfTextSecondary)
                Spacer()
            }
        }
        .font(.subheadline)
        .padding(Spacing.lg)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private func toolbarMenu(_ conversation: Conversation) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                NavigationLink(value: Route.petID(conversation.listingID)) {
                    Label("View \(conversation.listingName)", systemImage: "pawprint")
                }
                if me == conversation.adopterID {
                    NavigationLink(value: Route.shelter(id: conversation.listerID)) {
                        Label("View \(conversation.listerName)", systemImage: "person.crop.circle")
                    }
                }
                Divider()
                Button("Report", systemImage: "flag") {
                    reportedMessageID = nil
                    showReport = true
                }
                if conversation.isBlockedByMe(me) {
                    Button("Unblock", systemImage: "hand.raised.slash") { store.setBlocked(false, conversationID) }
                } else if !conversation.isBlocked {
                    Button("Block", systemImage: "hand.raised", role: .destructive) { confirmBlock = true }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More")
        }
    }

    // MARK: - Status

    /// "Sending…", "Sent", or "Read", shown under my latest message.
    private func status(of message: ChatMessage, in conversation: Conversation, other: String) -> String {
        if message.isPending { return network.isOnline ? "Sending…" : "Waiting to send" }
        if let read = conversation.lastRead[other], read >= message.createdAt { return "Read" }
        return "Sent"
    }

    /// The other person typed within the last few seconds.
    private func isOtherTyping(_ conversation: Conversation, other: String, now: Date) -> Bool {
        guard let typedAt = conversation.typing[other] else { return false }
        return now.timeIntervalSince(typedAt) < 8
    }

    // MARK: - Sending

    private func sendDraft(skipChecks: Bool = false) {
        let text = draft
        if !skipChecks {
            switch ContentModerator.check(text) {
            case .ok: break
            case .blocked(let reason):
                blockedMessage = reason
                return
            case .warning(let reason):
                moderationWarning = reason
                return
            }
        }
        store.send(text: text, photo: nil, in: conversationID)
        draft = ""
    }

    private func sendPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let small = ImageCompressor.chatPhoto(from: data) {
                store.send(text: nil, photo: small, in: conversationID)
            }
            photoItem = nil
        }
    }

    /// Tells the other person I'm typing, at most every few seconds, and stops after a pause.
    private func draftChanged(_ text: String) {
        typingTask?.cancel()
        if text.isEmpty {
            store.setTyping(false, in: conversationID)
            lastTypingSent = .distantPast
            return
        }
        if Date.now.timeIntervalSince(lastTypingSent) > 2.5 {
            store.setTyping(true, in: conversationID)
            lastTypingSent = .now
        }
        typingTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            store.setTyping(false, in: conversationID)
            lastTypingSent = .distantPast
        }
    }
}

/// A photo to show full screen (`fullScreenCover(item:)` needs something Identifiable).
private struct ViewerImage: Identifiable {
    let id: String
    let image: UIImage
}

/// Decoded chat photos, so scrolling doesn't decode them again and again.
private enum ChatImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(id: String, base64: String) -> UIImage? {
        if let cached = cache.object(forKey: id as NSString) { return cached }
        guard let data = Data(base64Encoded: base64), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: id as NSString)
        return image
    }
}

// MARK: - Pieces

private struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let proposerName: String
    let onMeetupAction: (MeetupAction) -> Void
    let statusText: String?
    let onTapImage: (UIImage) -> Void
    let onReport: () -> Void

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            if let meetup = message.meetup {
                MeetupCard(meetup: meetup, isMine: isMine, proposerName: proposerName, onAction: onMeetupAction)
                    .opacity(message.isPending ? 0.7 : 1)
            } else {
                textBubble
            }

            HStack(spacing: Spacing.xs) {
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                if let statusText { Text("· \(statusText)") }
            }
            .font(.pfCaption)
            .foregroundStyle(Color.pfTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .padding(isMine ? .leading : .trailing, message.meetup == nil ? 48 : 16)
        .accessibilityElement(children: message.meetup == nil ? .combine : .contain)
    }

    private var textBubble: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let base64 = message.imageBase64, let image = ChatImageCache.image(id: message.id, base64: base64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: 220, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                    .onTapGesture { onTapImage(image) }
                    .accessibilityLabel("Photo")
                    .accessibilityAddTraits(.isButton)
            }
            if let text = message.text {
                Text(text)
                    .foregroundStyle(isMine ? Color.pfSurfaceElevated : Color.pfTextPrimary)
            }
        }
        .padding(Spacing.md)
        .background(isMine ? Color.pfBrandPrimary : Color.pfSurface,
                    in: RoundedRectangle(cornerRadius: Radius.large))
        .overlay {
            if !isMine {
                RoundedRectangle(cornerRadius: Radius.large).stroke(Color.pfBorder)
            }
        }
        .opacity(message.isPending ? 0.7 : 1)
        .contextMenu {
            if let text = message.text {
                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = text }
            }
            if !isMine {
                Button("Report message", systemImage: "flag", action: onReport)
            }
        }
    }
}

private struct TypingIndicator: View {
    let name: String
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.pfTextSecondary)
                        .frame(width: 7, height: 7)
                        .opacity(animate ? 1 : 0.3)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2),
                                   value: animate)
                }
            }
            .padding(Spacing.md)
            .background(Color.pfSurface, in: Capsule())
            Text("\(name) is typing…")
                .font(.pfCaption)
                .foregroundStyle(Color.pfTextSecondary)
            Spacer()
        }
        .onAppear { animate = true }
        .accessibilityElement(children: .combine)
    }
}

/// Full-screen photo with a close button.
private struct ImageViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Photo viewers are always black, in light and dark mode.
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .padding()
            .accessibilityLabel("Close")
        }
    }
}
