import SwiftUI

/// Top of Discover when browsing: a greeting, quick shortcuts, and the
/// "Pet of the day".
struct DiscoverHeader: View {
    let filters: PetFilters
    /// Pets to pick the Pet of the day from.
    let pool: [Pet]

    @Environment(ProfileStore.self) private var profileStore
    @Environment(AuthManager.self) private var auth
    @Environment(ApplicationsStore.self) private var applications
    @Environment(Router.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(greeting)
                    .font(.pfTitle)
                    .foregroundStyle(Color.pfTextPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    quickAction("Swipe", icon: "rectangle.stack") { router.push(.swipe(filters)) }
                    quickAction("Listers near me", icon: "map") { router.selectedTab = .map }
                    quickAction("Breed match", icon: "pawprint.circle") { router.selectedTab = .identify }
                    quickAction("Saved searches", icon: "bookmark") { router.push(.savedSearches) }
                    quickAction("Care Hub", icon: "book") { router.open(.careHub, in: .profile) }
                }
            }

            if let pet = petOfTheDay {
                NavigationLink(value: Route.petDetail(pet)) {
                    PetOfTheDayCard(pet: pet)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let timeOfDay = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        let name = profileStore.profile.displayName.isEmpty
            ? auth.user?.displayName ?? ""
            : profileStore.profile.displayName
        let firstName = name.split(separator: " ").first.map(String.init) ?? ""
        return firstName.isEmpty ? "\(timeOfDay)!" : "\(timeOfDay), \(firstName)!"
    }

    private var subtitle: String {
        if let active = applications.applications.first(where: \.isActive) {
            return "Your application for \(active.pet.name) is \(active.status.rawValue.lowercased())."
        }
        return "Let's find your new best friend."
    }

    /// Same pet all day, a different one tomorrow.
    private var petOfTheDay: Pet? {
        let candidates = pool.filter { !$0.isAdopted }
        guard !candidates.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return candidates[day % candidates.count]
    }

    private func quickAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.pfBrandPrimary)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 44)
                .background(Color.pfBrandDeep, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A big featured card with a "Pet of the day" ribbon.
private struct PetOfTheDayCard: View {
    let pet: Pet

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .frame(height: 220)
                .overlay { PetPhoto(url: pet.photoURLs.first ?? pet.thumbnailURL, species: pet.species) }
                .clipped()
            // Dark fade so white text is readable on any photo.
            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Label("Pet of the day", systemImage: "sparkles")
                    .font(.pfCaption.weight(.bold))
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Color.pfBrandPrimary, in: Capsule())
                Text(pet.name)
                    .font(.title.bold())
                Text([pet.breed, pet.location].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
            }
            .foregroundStyle(.white)
            .padding(Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.large))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pet of the day: \(pet.name), \(pet.breed)")
    }
}
