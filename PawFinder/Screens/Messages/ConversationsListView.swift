import SwiftUI

/// Profile › Messages: every chat you're in, as an adopter or a lister, newest first.
struct ConversationsListView: View {
    @Environment(MessagesStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(Router.self) private var router

    var body: some View {
        Group {
            if auth.user == nil {
                EmptyStateView(icon: "bubble.left.and.bubble.right", title: "Sign in to chat",
                               message: "Messages are between you and the person listing a pet, so you need an account.",
                               buttonTitle: "Sign in") { router.showSignIn = true }
            } else if store.conversations.isEmpty {
                if store.isLoaded {
                    EmptyStateView(icon: "bubble.left.and.bubble.right", title: "No messages yet",
                                   message: "Have a question about a pet? Tap \"Message\" on their page. Messages from adopters about your listings show up here too.",
                                   buttonTitle: "Find a pet") { router.selectedTab = .discover }
                } else {
                    LoadingView(message: "Loading messages...")
                }
            } else {
                List {
                    ForEach(store.conversations) { conversation in
                        NavigationLink(value: Route.conversation(conversation.id)) {
                            ConversationRow(conversation: conversation, me: store.userID ?? "")
                        }
                        .listRowBackground(Color.pfSurface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.pfBackground)
        .navigationTitle("Messages")
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    let me: String

    var body: some View {
        let unread = conversation.unreadCount(for: me)
        HStack(spacing: Spacing.md) {
            Color.clear
                .frame(width: 52, height: 52)
                .overlay { PetPhoto(url: PhotoURL.thumbnail(of: conversation.listingID), species: conversation.listingSpecies) }
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(conversation.otherName(for: me))
                        .font(.pfHeadline)
                        .foregroundStyle(Color.pfTextPrimary)
                        .lineLimit(1)
                    Spacer()
                    if !conversation.lastMessage.isEmpty {
                        Text(conversation.lastMessageAt.formatted(.relative(presentation: .named)))
                            .font(.pfCaption)
                            .foregroundStyle(Color.pfTextSecondary)
                    }
                }
                Text(conversation.subtitle(for: me))
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
                    .lineLimit(1)
                HStack {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(unread > 0 ? Color.pfTextPrimary : Color.pfTextSecondary)
                        .fontWeight(unread > 0 ? .semibold : .regular)
                        .lineLimit(1)
                    Spacer()
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.pfCaption.weight(.bold))
                            .foregroundStyle(Color.pfSurfaceElevated)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.pfBrandPrimary, in: Capsule())
                            .accessibilityLabel("\(unread) unread")
                    }
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var preview: String {
        if conversation.isBlocked { return "Blocked" }
        if conversation.lastMessage.isEmpty { return "No messages yet" }
        return conversation.lastSenderID == me ? "You: \(conversation.lastMessage)" : conversation.lastMessage
    }
}
