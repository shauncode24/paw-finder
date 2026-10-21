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
         "Find a pet you love, tap \"Apply to adopt\", and fill in the application. The shelter reviews it, may ask for a chat or meet-and-greet, and then lets you know their decision. You can follow every step under Profile › My applications."),
        ("Are the pets real?",
         "With Petfinder connected, yes: listings come from real shelters and rescues. If Petfinder can't be reached, PawFinder shows sample pets (you'll see a banner) so you can still look around."),
        ("Who answers my messages and applications?",
         "In this version, shelter replies are simulated so you can try the whole journey. Real shelter messaging is planned."),
        ("Why do I need an account?",
         "You don't! You can browse, favorite, and apply as a guest. An account keeps your profile with you and is needed for a few things like deleting your data from our servers later."),
        ("How do I get told when a pet is adopted?",
         "Favorite the pet and turn on notifications. PawFinder checks now and then and lets you know if their status changes."),
        ("What does the breed match score mean?",
         "It compares each breed's typical traits with your lifestyle answers (home, kids, schedule, activity). It's a guide, not a rule: every pet is an individual, and many shelter pets are wonderful mixes."),
        ("Can I use PawFinder without location?",
         "Yes. Type a ZIP code or city in Discover's filters or on the Map instead."),
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
                Text("PawFinder helps people find and adopt pets from shelters and rescues. Every adoption frees up space for another animal in need.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.pfTextPrimary)

                PFCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        credit("Pet listings", "Powered by Petfinder", url: "https://www.petfinder.com")
                        credit("Sample photos", "placedog.net and cataas.com", url: nil)
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
         "If you allow it, your location is used only while you use the app, to sort pets and shelters by distance. It's sent to Petfinder as part of a search and isn't stored by us."),
        ("Photos",
         "Photos you add to applications or messages, and your profile photo, stay on your device."),
        ("Pet listings",
         "Searches are sent to Petfinder to find pets and shelters. Petfinder's own privacy policy applies to that service."),
        ("Your choices",
         "You can export your data (Profile › Account › Export my data), erase everything on this phone (Settings), and turn notifications or location off at any time in iPhone Settings."),
        ("Contact",
         "Questions? Email \(SupportInfo.email)."),
    ])

    static let terms = LegalTextView(title: "Terms of Use", updated: "October 2026", sections: [
        ("Using PawFinder",
         "PawFinder helps you find adoptable pets and contact shelters. Adoption decisions, fees, and policies are set by each shelter, not by PawFinder."),
        ("Listings",
         "Pet and shelter information comes from the shelters (via Petfinder). We do our best to keep it current, but a pet may already be adopted or details may change."),
        ("Be kind",
         "Don't send abusive messages, spam, or anything illegal. Never send money before meeting a pet in person; report any listing or message that asks you to."),
        ("Your account",
         "Keep your password safe. You can stop using PawFinder and delete your account at any time."),
        ("No guarantees",
         "PawFinder is provided as is. We're not responsible for agreements between you and a shelter."),
    ])
}

// MARK: - Adoption celebration

/// Shown when the user marks an adoption complete. Confetti (skipped with
/// Reduce Motion), a share button, and afterwards a polite App Store review prompt.
struct AdoptionCelebrationView: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
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
