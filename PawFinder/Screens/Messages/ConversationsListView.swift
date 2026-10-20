import SwiftUI

/// Profile › Messages: all chats with shelters, newest first.
struct ConversationsListView: View {
    @Environment(MessagesStore.self) private var store

    var body: some View {
        Group {
            if store.conversations.isEmpty {
                EmptyStateView(icon: "bubble.left.and.bubble.right", title: "No messages yet",
                               message: "Have a question about a pet? Tap \"Message shelter\" on their page.")
            } else {
                List {
                    ForEach(store.conversations) { conversation in
                        NavigationLink(value: Route.conversation(conversation.id)) {
                            ConversationRow(conversation: conversation)
                        }
                        .listRowBackground(Color.pfSurface)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.conversations[$0].id }
                        ids.forEach(store.delete)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("Messages")
        // Pick up simulated replies while the list is open.
        .task {
            while !Task.isCancelled {
                store.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: Spacing.md) {
            Group {
                if let pet = conversation.pet {
                    Color.clear.overlay { PetPhoto(url: pet.thumbnailURL, species: pet.species) }
                } else {
                    Image(systemName: "house.fill")
                        .foregroundStyle(Color.pfBrandLight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.pfBrandDeep)
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(conversation.title)
                        .font(.pfHeadline)
                        .foregroundStyle(Color.pfTextPrimary)
                        .lineLimit(1)
                    Spacer()
                    if let date = conversation.lastMessage?.date {
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.pfCaption)
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                }
                if let subtitle = conversation.subtitle {
                    Text(subtitle)
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                }
                HStack {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(conversation.unreadCount > 0 ? Color.pfTextPrimary : Color.pfTextSecondary)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.pfCaption.weight(.bold))
                            .foregroundStyle(Color.pfSurfaceElevated)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.pfBrandPrimary, in: Capsule())
                            .accessibilityLabel("\(conversation.unreadCount) unread")
                    }
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var preview: String {
        if conversation.isBlocked { return "Blocked" }
        guard let last = conversation.lastMessage else { return "" }
        let prefix = last.sender == .me ? "You: " : ""
        return prefix + (last.text ?? "📷 Photo")
    }
}
