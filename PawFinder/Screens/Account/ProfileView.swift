import SwiftUI

/// The Profile tab: who you are, your lifestyle answers, and links to
/// followed shelters, settings, and your account.
struct ProfileView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ProfileStore.self) private var profileStore
    @Environment(ApplicationsStore.self) private var applications
    @Environment(MessagesStore.self) private var messages
    @State private var showAuth = false

    var body: some View {
        List {
            Section {
                header
                if auth.user == nil {
                    PFButton(title: "Sign in or create account") { showAuth = true }
                        .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.lg, bottom: Spacing.md, trailing: Spacing.lg))
                }
            }
            .listRowBackground(Color.pfSurface)

            Section("Your lifestyle") {
                NavigationLink(value: Route.lifestyle) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        if profileStore.profile.isQuestionnaireComplete {
                            Text(profileStore.profile.lifestyleSummary)
                                .foregroundStyle(Color.pfTextPrimary)
                            Text("Edit your answers")
                                .font(.pfCaption)
                                .foregroundStyle(Color.pfTextSecondary)
                        } else {
                            Text("Tell us about your home")
                                .foregroundStyle(Color.pfTextPrimary)
                            Text("\(profileStore.profile.answeredCount) of \(AdopterProfile.questionCount) answered · helps us suggest a good match")
                                .font(.pfCaption)
                                .foregroundStyle(Color.pfTextSecondary)
                        }
                    }
                }
            }
            .listRowBackground(Color.pfSurface)

            Section {
                NavigationLink(value: Route.messages) {
                    HStack {
                        Label("Messages", systemImage: "bubble.left.and.bubble.right")
                        Spacer()
                        if messages.unreadCount > 0 {
                            Text("\(messages.unreadCount)")
                                .font(.pfCaption.weight(.bold))
                                .foregroundStyle(Color.pfSurfaceElevated)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, 2)
                                .background(Color.pfBrandPrimary, in: Capsule())
                                .accessibilityLabel("\(messages.unreadCount) unread")
                        }
                    }
                }
                NavigationLink(value: Route.applications) {
                    HStack {
                        Label("My applications", systemImage: "doc.text")
                        Spacer()
                        let active = applications.applications.filter(\.isActive).count
                        if active > 0 {
                            Text("\(active) active")
                                .font(.pfCaption)
                                .foregroundStyle(Color.pfTextSecondary)
                        }
                    }
                }
                NavigationLink(value: Route.careHub) {
                    Label("Care Hub", systemImage: "book")
                }
                NavigationLink(value: Route.editProfile) {
                    Label("Edit profile", systemImage: "person.crop.circle")
                }
                NavigationLink(value: Route.followedShelters) {
                    Label("Followed shelters", systemImage: "star")
                }
                if auth.user != nil {
                    NavigationLink(value: Route.account) {
                        Label("Account", systemImage: "key")
                    }
                }
                NavigationLink(value: Route.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
                #if DEBUG
                NavigationLink(value: Route.designSystem) {
                    Label("Design system", systemImage: "paintpalette")
                }
                #endif
            }
            .listRowBackground(Color.pfSurface)
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showAuth) { AuthSheet() }
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            AvatarView(image: profileStore.avatar, size: 64)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(displayName)
                    .font(.pfTitle)
                    .foregroundStyle(Color.pfTextPrimary)
                Text(auth.user?.accountLabel ?? "Browsing as a guest")
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private var displayName: String {
        let name = profileStore.profile.displayName
        if !name.isEmpty { return name }
        return auth.user?.displayName ?? "Guest"
    }
}

/// Round profile photo, or a placeholder person icon.
struct AvatarView: View {
    let image: UIImage?
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(Color.pfBrandLight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.pfBrandDeep)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
