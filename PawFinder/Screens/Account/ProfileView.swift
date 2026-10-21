import SwiftUI

/// The Profile tab: who you are, your lifestyle answers, and links to
/// followed shelters, settings, and your account.
struct ProfileView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ProfileStore.self) private var profileStore
    @Environment(ApplicationsStore.self) private var applications
    @Environment(MessagesStore.self) private var messages
    @Environment(FavoritesStore.self) private var favorites
    @Environment(FollowedSheltersStore.self) private var followed
    @Environment(Router.self) private var router
    @State private var showAuth = false

    var body: some View {
        List {
            Section {
                header
                stats
                if auth.user == nil {
                    PFButton(title: "Sign in or create account") { showAuth = true }
                        .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.lg, bottom: Spacing.md, trailing: Spacing.lg))
                }
            }
            .listRowBackground(Color.pfSurface)

            if !adopted.isEmpty {
                Section("Your family 🏡") {
                    ForEach(adopted) { application in
                        NavigationLink(value: Route.applicationDetail(application.id)) {
                            HStack(spacing: Spacing.md) {
                                Color.clear
                                    .frame(width: 44, height: 44)
                                    .overlay { PetPhoto(url: application.pet.thumbnailURL, species: application.pet.species) }
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(application.pet.name)
                                        .font(.pfHeadline)
                                        .foregroundStyle(Color.pfTextPrimary)
                                    if let date = application.events.last(where: { $0.status == .adopted })?.date {
                                        Text("Adopted \(date.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.pfCaption)
                                            .foregroundStyle(Color.pfTextSecondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Color.pfSurface)
            }

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
                NavigationLink(value: Route.help) {
                    Label("Help & FAQ", systemImage: "questionmark.circle")
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

    private var adopted: [AdoptionApplication] {
        applications.applications.filter { $0.status == .adopted }
    }

    /// "5 favorites · 1 application · 2 shelters", each tappable.
    private var stats: some View {
        HStack(spacing: Spacing.sm) {
            statTile(favorites.favorites.count, "Favorites") { router.selectedTab = .favorites }
            statTile(applications.applications.filter { $0.status != .draft }.count, "Applications") {
                router.push(.applications)
            }
            statTile(followed.shelters.count, "Shelters") { router.push(.followedShelters) }
        }
        .padding(.bottom, Spacing.sm)
    }

    private func statTile(_ value: Int, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.pfTitle)
                    .foregroundStyle(Color.pfTextPrimary)
                Text(title)
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(Color.pfBrandDeep, in: RoundedRectangle(cornerRadius: Radius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value) \(title)")
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
