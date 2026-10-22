import SwiftUI

/// First-launch flow: welcome → account (or guest) → lifestyle → location.
/// Shown once; `hasCompletedOnboarding` is saved when it finishes.
struct OnboardingView: View {
    enum Step {
        case welcome, account, lifestyle, location
    }

    let onFinish: () -> Void

    @State private var step: Step = .welcome
    @Environment(AuthManager.self) private var auth
    @Environment(LocationService.self) private var locationService

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .welcome: welcome
                case .account: account
                case .lifestyle:
                    LifestyleQuestionnaireView(saveTitle: "Continue", onFinish: { go(to: .location) }, showsSkip: true)
                case .location: location
                }
            }
            .background(Color.pfBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .welcome {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") { goBack() }
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private var title: String {
        switch step {
        case .welcome: ""
        case .account: "Your account"
        case .lifestyle: "Your lifestyle"
        case .location: "Pets near you"
        }
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 96))
                .foregroundStyle(Color.pfBrandPrimary)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.sm) {
                Text("Welcome to PawFinder")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.pfTextPrimary)
                Text("Find your new best friend.")
                    .font(.title3)
                    .foregroundStyle(Color.pfTextSecondary)
            }
            .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: Spacing.md) {
                feature("magnifyingglass", "Browse adoptable pets near you")
                feature("heart", "Save favorites and get told when they're adopted")
                feature("map", "Follow listers near you and hear about new pets")
            }
            .padding(.horizontal, Spacing.lg)
            Spacer()
            PFButton(title: "Get started") { go(to: .account) }
        }
        .padding(Spacing.xl)
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text).foregroundStyle(Color.pfTextPrimary)
        } icon: {
            Image(systemName: icon).foregroundStyle(Color.pfBrandPrimary)
        }
    }

    private var account: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                if let user = auth.user {
                    Label("Signed in as \(user.displayName ?? user.accountLabel)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.pfSuccess)
                    PFButton(title: "Continue") { go(to: .lifestyle) }
                } else {
                    Text("An account keeps your profile with you. You can also look around as a guest and sign in later.")
                        .foregroundStyle(Color.pfTextSecondary)
                    AuthView { go(to: .lifestyle) }
                    Button("Continue as guest") { go(to: .lifestyle) }
                        .font(.pfHeadline)
                        .padding(.top, Spacing.sm)
                }
            }
            .padding(Spacing.lg)
        }
    }

    private var location: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.pfBrandPrimary)
                .accessibilityHidden(true)
            Text("Show pets and listers near you?")
                .font(.pfTitle)
                .foregroundStyle(Color.pfTextPrimary)
                .multilineTextAlignment(.center)
            Text("We only use your location while you're using the app, to sort pets and listers by distance. You can always type a postcode instead.")
                .foregroundStyle(Color.pfTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            PFButton(title: "Allow location") {
                Task {
                    _ = try? await locationService.requestLocation()
                    onFinish()
                }
            }
            Button("Not now", action: onFinish)
                .font(.pfHeadline)
        }
        .padding(Spacing.xl)
    }

    // MARK: - Navigation

    private func go(to next: Step) {
        withAnimation { step = next }
    }

    private func goBack() {
        switch step {
        case .welcome: break
        case .account: go(to: .welcome)
        case .lifestyle: go(to: .account)
        case .location: go(to: .lifestyle)
        }
    }
}
