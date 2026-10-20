import PhotosUI
import SwiftUI

/// One chat: message bubbles grouped by day, read receipts, "typing…",
/// photo messages, and a composer. Offline messages wait in the outbox.
struct ChatView: View {
    let conversationID: UUID

    @Environment(MessagesStore.self) private var store
    @Environment(NetworkMonitor.self) private var network

    @State private var draft = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var visibleCount = 40
    @State private var moderationWarning: String?
    @State private var blockedMessage: String?
    @State private var showReport = false
    @State private var reportedMessageID: UUID?
    @State private var confirmBlock = false
    @State private var fullScreenImage: ViewerImage?
    @FocusState private var composerFocused: Bool

    private static let pageSize = 40

    var body: some View {
        Group {
            if let conversation = store.conversation(conversationID) {
                // Re-evaluated every second, for read receipts and "typing…".
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    content(conversation, now: context.date)
                }
            } else {
                EmptyStateView(icon: "bubble.left", title: "Chat not found", message: "It may have been deleted.")
            }
        }
        .background(Color.pfBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            NotificationManager.shared.openConversationID = conversationID
            while !Task.isCancelled {
                store.refresh()
                store.markRead(conversationID)
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onDisappear {
            if NotificationManager.shared.openConversationID == conversationID {
                NotificationManager.shared.openConversationID = nil
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    store.send(text: nil, imageData: data, in: conversationID, isOnline: network.isOnline)
                }
                photoItem = nil
            }
        }
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
        .confirmationDialog("Block this shelter?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) { store.setBlocked(true, conversationID) }
        } message: {
            Text("You won't get messages from them in this chat. You can unblock any time.")
        }
        .fullScreenCover(item: $fullScreenImage) { image in
            ImageViewer(url: image.url)
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
            messageList(conversation, now: now)
            if conversation.isBlocked {
                blockedBar
            } else {
                composer
            }
        }
        .navigationTitle(conversation.title)
        .toolbar { toolbarMenu(conversation) }
    }

    private func messageList(_ conversation: Conversation, now: Date) -> some View {
        let messages = Array(conversation.messages.suffix(visibleCount))
        let lastMine = conversation.messages.last { $0.sender == .me }?.id
        let typing = conversation.pendingReplies.contains { $0.isTyping(at: now) }

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    if conversation.messages.count > visibleCount {
                        Button("Load earlier messages") { visibleCount += Self.pageSize }
                            .font(.subheadline)
                            .padding(.vertical, Spacing.sm)
                    }
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        if index == 0 || !Calendar.current.isDate(message.date, inSameDayAs: messages[index - 1].date) {
                            Text(message.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.pfCaption)
                                .foregroundStyle(Color.pfTextSecondary)
                                .padding(.top, Spacing.sm)
                        }
                        MessageBubble(
                            message: message,
                            imageURL: message.imageFile.map(store.imageURL),
                            showsStatus: message.id == lastMine,
                            now: now,
                            onTapImage: { fullScreenImage = ViewerImage(url: $0) },
                            onReport: {
                                reportedMessageID = message.id
                                showReport = true
                            }
                        )
                        .id(message.id)
                    }
                    if typing {
                        TypingIndicator(name: conversation.shelterName)
                            .id("typing")
                    }
                }
                .padding(Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: conversation.messages.count) {
                if let last = conversation.messages.last?.id {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
            .onChange(of: typing) {
                if typing { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
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

    private var blockedBar: some View {
        HStack {
            Text("You blocked this shelter.")
                .foregroundStyle(Color.pfTextSecondary)
            Spacer()
            Button("Unblock") { store.setBlocked(false, conversationID) }
        }
        .font(.subheadline)
        .padding(Spacing.lg)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private func toolbarMenu(_ conversation: Conversation) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if let pet = conversation.pet {
                    NavigationLink(value: Route.petDetail(pet)) {
                        Label("View \(pet.name)", systemImage: "pawprint")
                    }
                }
                NavigationLink(value: Route.shelter(id: conversation.shelterID)) {
                    Label("View shelter", systemImage: "house")
                }
                Divider()
                Button("Report", systemImage: "flag") {
                    reportedMessageID = nil
                    showReport = true
                }
                if conversation.isBlocked {
                    Button("Unblock", systemImage: "hand.raised.slash") { store.setBlocked(false, conversationID) }
                } else {
                    Button("Block", systemImage: "hand.raised", role: .destructive) { confirmBlock = true }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More")
        }
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
        store.send(text: text, imageData: nil, in: conversationID, isOnline: network.isOnline)
        draft = ""
    }
}

/// A photo to show full screen (`fullScreenCover(item:)` needs something Identifiable).
private struct ViewerImage: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - Pieces

private struct MessageBubble: View {
    let message: Message
    let imageURL: URL?
    let showsStatus: Bool
    let now: Date
    let onTapImage: (URL) -> Void
    let onReport: () -> Void

    var body: some View {
        if message.sender == .system {
            Text(message.text ?? "")
                .font(.pfCaption)
                .foregroundStyle(Color.pfTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
                .frame(maxWidth: .infinity)
        } else {
            let isMine = message.sender == .me
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if let imageURL, let image = UIImage(contentsOfFile: imageURL.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 220, maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                            .onTapGesture { onTapImage(imageURL) }
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
                .contextMenu {
                    if let text = message.text {
                        Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = text }
                    }
                    if !isMine {
                        Button("Report message", systemImage: "flag", action: onReport)
                    }
                }

                HStack(spacing: Spacing.xs) {
                    Text(message.date.formatted(date: .omitted, time: .shortened))
                    if isMine, showsStatus { Text("· \(statusText)") }
                }
                .font(.pfCaption)
                .foregroundStyle(Color.pfTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
            .padding(isMine ? .leading : .trailing, 48)
            .accessibilityElement(children: .combine)
        }
    }

    private var statusText: String {
        switch message.status(at: now) {
        case .waiting: "Waiting to send"
        case .sent: "Sent"
        case .delivered: "Delivered"
        case .read: "Read"
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
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Photo viewers are always black, in light and dark mode.
            Color.black.ignoresSafeArea()
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
