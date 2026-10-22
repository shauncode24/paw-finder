import StoreKit
import SwiftUI

/// Where "Send feedback" emails go. Replace with a real address before release.
enum SupportInfo {
    static let email = "support@pawfinder.example"

    static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    /// A pre-filled feedback email with the app and iOS version.
    static var feedbackURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "PawFinder feedback"),
            URLQueryItem(name: "body", value: "\n\n---\nPawFinder \(appVersion) · iOS \(UIDevice.current.systemVersion)"),
        ]
        return components.url
    }
}

// MARK: - Help & FAQ

struct HelpView: View {
    private let faqs: [(String, String)] = [
        ("How does adopting through PawFinder work?",
         "Find a pet you love, tap \"Apply to adopt\", and fill in the application. The lister reviews it, may ask for a chat or meet-and-greet, and then lets you know their decision. You can follow every step under Profile › My applications."),
        ("Are the pets real?",
         "Yes. Every pet is listed by a real person or rescue using PawFinder, and shows up here the moment they post. Chat with the lister before applying, and never send money before meeting a pet in person."),
        ("Who answers my messages and applications?",
         "The person or rescue who listed the pet. Tap \"Message\" on any pet's page to chat with them, and you'll be notified when they reply. Applications go to them too, and you can follow the status in My applications."),
        ("Why do I need an account?",
         "You can browse and favorite pets as a guest. An account is needed to message a lister, apply to adopt, or list a pet, because those involve another real person."),
        ("How do I list a pet for adoption?",
         "Go to Profile › \"List a pet for adoption\". The first time, you set up a short lister profile (as an individual or a rescue). Then add the pet's photos and details. It's the same account you use to adopt, with no separate login. Manage your pets and the applications you receive from the same section."),
        ("How do I get told when a pet is adopted?",
         "Favorite the pet and turn on notifications. PawFinder checks now and then and lets you know if their status changes."),
        ("What does the breed match score mean?",
         "It compares each breed's typical traits with your lifestyle answers (home, kids, schedule, activity). It's a guide, not a rule: every pet is an individual, and many shelter pets are wonderful mixes."),
        ("Can I use PawFinder without location?",
         "Yes. Type a postcode or city in Discover's filters or on the Map instead."),
        ("How do I delete my data?",
         "Settings › Erase all data on this phone removes everything stored on your device. To delete your account too, go to Profile › Account › Delete account."),
    ]

    var body: some View {
        List {
            Section("Frequently asked questions") {
                ForEach(faqs, id: \.0) { question, answer in
                    DisclosureGroup {
                        Text(answer)
                            .font(.subheadline)
                            .foregroundStyle(Color.pfTextSecondary)
                            .padding(.vertical, Spacing.xs)
                    } label: {
                        Text(question).foregroundStyle(Color.pfTextPrimary)
                    }
                    .listRowBackground(Color.pfSurface)
                }
            }
            Section("Still need help?") {
                if let url = SupportInfo.feedbackURL {
                    Link(destination: url) {
                        Label("Email us", systemImage: "envelope")
                    }
                    .listRowBackground(Color.pfSurface)
                }
                NavigationLink(value: Route.careHub) {
                    Label("Read the Care Hub guides", systemImage: "book")
                }
                .listRowBackground(Color.pfSurface)
            }
        }
        .tint(Color.pfBrandPrimary)
        .scrollContentBackground(.hidden)
        .background(Color.pfBackground)
        .navigationTitle("Help & FAQ")
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.pfBrandPrimary)
                    .accessibilityHidden(true)
                VStack(spacing: Spacing.xs) {
                    Text("PawFinder")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.pfTextPrimary)
                    Text("Version \(SupportInfo.appVersion)")
                        .font(.subheadline)
                        .foregroundStyle(Color.pfTextSecondary)
                }
                Text("PawFinder connects people who have pets to rehome with people ready to adopt them. Every adoption frees up space for another animal in need.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.pfTextPrimary)

                PFCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        credit("Pet listings", "Posted by PawFinder users", url: nil)
                        credit("Maps", "Apple MapKit", url: nil)
                        credit("Accounts", "Firebase Authentication", url: nil)
                    }
                }

                Text("Made with care for shelter pets everywhere. 🐾")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
            }
            .padding(Spacing.xl)
        }
        .background(Color.pfBackground)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func credit(_ title: String, _ value: String, url: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.pfCaption).foregroundStyle(Color.pfTextSecondary)
            if let url, let link = URL(string: url) {
                Link(value, destination: link)
            } else {
                Text(value).foregroundStyle(Color.pfTextPrimary)
            }
        }
    }
}

// MARK: - Privacy policy & terms

/// A simple long-form text page.
struct LegalTextView: View {
    let title: String
    let updated: String
    let sections: [(String, String)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Last updated \(updated)")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
                ForEach(sections, id: \.0) { heading, text in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(heading)
                            .font(.pfHeadline)
                            .foregroundStyle(Color.pfTextPrimary)
                        Text(text)
                            .foregroundStyle(Color.pfTextPrimary)
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .background(Color.pfBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    static let privacy = LegalTextView(title: "Privacy Policy", updated: "October 2026", sections: [
        ("The short version",
         "Your favorites, applications, messages, notes, and photos are stored on your phone. We don't sell your data, show ads, or track you across other apps."),
        ("Your account",
         "If you create an account, your email (or username), name, and a secure password hash are stored by Firebase Authentication (Google) so you can sign in. You can delete your account at any time in Profile › Account."),
        ("Location",
         "If you allow it, your location is used only while you use the app, to sort pets and listers by distance. Listers also give an approximate location (a city or postcode) that's shown with their listings."),
        ("Photos",
         "Photos you add to applications or messages, and your profile photo, stay on your device."),
        ("Pet listings",
         "Listings, lister profiles, chats, and applications are stored in Google Firebase (Firestore) so they can be shared between people. Listings and lister profiles are public. Chats are visible only to the two people in them, and applications only to the applicant and the lister."),
        ("Your choices",
         "You can export your data (Profile › Account › Export my data), erase everything on this phone (Settings), and turn notifications or location off at any time in iPhone Settings."),
        ("Contact",
         "Questions? Email \(SupportInfo.email)."),
    ])

    static let terms = LegalTextView(title: "Terms of Use", updated: "October 2026", sections: [
        ("Using PawFinder",
         "PawFinder helps you find adoptable pets and contact the people listing them. Adoption decisions, fees, and policies are set by each lister, not by PawFinder."),
        ("Listings",
         "Listings are written by the people and rescues who post them. PawFinder doesn't verify them. A pet may already be adopted or details may change, so ask the lister before you travel."),
        ("Be kind",
         "Don't send abusive messages, spam, or anything illegal. Never send money before meeting a pet in person; report any listing or message that asks you to."),
        ("Your account",
         "Keep your password safe. You can stop using PawFinder and delete your account at any time."),
        ("No guarantees",
         "PawFinder is provided as is. We're not responsible for agreements between you and a lister."),
    ])
}

// MARK: - Adoption celebration

/// Shown when the user marks an adoption complete. Confetti (skipped with
/// Reduce Motion), a share button, and afterwards a polite App Store review prompt.
struct AdoptionCelebrationView: View {
    let pet: Pet
    /// When set, a "Rate the lister" button is shown; `onRate` runs after the screen closes.
    var rateTitle: String? = nil
    var onRate: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dropped = false

    var body: some View {
        ZStack {
            Color.pfBackground.ignoresSafeArea()
            if !reduceMotion { confetti }

            VStack(spacing: Spacing.xl) {
                Spacer()
                Color.clear
                    .frame(width: 160, height: 160)
                    .overlay { PetPhoto(url: pet.thumbnailURL, species: pet.species) }
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.pfBrandPrimary, lineWidth: 4))
                Text("Welcome home, \(pet.name)! 🎉")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.pfTextPrimary)
                Text("Thank you for adopting. You've given \(pet.name) a family, and made room at the shelter for another animal in need.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.pfTextSecondary)
                Spacer()
                ShareLink(item: "We just adopted \(pet.name)! 🐾 Found through PawFinder.") {
                    Label("Share the news", systemImage: "square.and.arrow.up")
                        .font(.pfHeadline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(Color.pfSurfaceElevated)
                        .background(Color.pfBrandPrimary, in: RoundedRectangle(cornerRadius: Radius.medium))
                }
                if let rateTitle, let onRate {
                    PFButton(title: rateTitle) {
                        onRate()
                        dismiss()
                    }
                }
                PFButton(title: "Find a vet nearby", style: .secondary) {
                    dismiss()
                    router.push(.nearbyPlaces)
                }
                PFButton(title: "Done", style: .secondary) {
                    dismiss()
                    // A happy moment is the right time to ask (iOS limits how often it shows).
                    requestReview()
                }
            }
            .padding(Spacing.xl)
        }
        .sensoryFeedback(.success, trigger: dropped)
        .onAppear { withAnimation(.easeIn(duration: 2.5)) { dropped = true } }
    }

    /// Simple falling confetti: colored dots that drop from the top once.
    private var confetti: some View {
        GeometryReader { proxy in
            ForEach(0..<40, id: \.self) { index in
                let colors: [Color] = [.pfBrandPrimary, .pfBrandLight, .pfSuccess, .pfBrandDeep]
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors[index % colors.count])
                    .frame(width: 8, height: 12)
                    .rotationEffect(.degrees(Double(index * 37)))
                    .position(x: proxy.size.width * CGFloat((index * 53) % 100) / 100,
                              y: dropped ? proxy.size.height + 40 : -20 - CGFloat((index * 29) % 200))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
