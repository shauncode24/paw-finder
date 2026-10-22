import SwiftUI

/// Our own short "why turn on notifications?" screen, shown before the
/// system prompt. People are far more likely to say yes with context, and a
/// "Not now" here doesn't use up the one-time system prompt.
struct NotificationPrimingView: View {
    let category: NotificationPreferences.Category

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.pfBrandPrimary)
                .accessibilityHidden(true)
                .padding(.top, Spacing.xl)

            VStack(spacing: Spacing.sm) {
                Text("Don't miss a match")
                    .font(.pfTitle)
                    .foregroundStyle(Color.pfTextPrimary)
                Text(headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.pfTextSecondary)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(NotificationPreferences.Category.allCases, id: \.self) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .foregroundStyle(item == category ? Color.pfBrandPrimary : Color.pfTextPrimary)
                        .fontWeight(item == category ? .semibold : .regular)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("You can pick which ones you get, and set quiet hours, in Settings.")
                .font(.pfCaption)
                .foregroundStyle(Color.pfTextSecondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            VStack(spacing: Spacing.sm) {
                PFButton(title: "Turn on notifications") {
                    Task {
                        await NotificationManager.shared.acceptPriming()
                    }
                }
                Button("Not now") { NotificationManager.shared.declinePriming() }
                    .font(.pfHeadline)
            }
        }
        .padding(Spacing.xl)
        .background(Color.pfBackground)
        .interactiveDismissDisabled()
    }

    /// Tailored to what the user just did.
    private var headline: String {
        switch category {
        case .favorites: "We'll let you know if a pet you saved gets adopted."
        case .shelters: "We'll tell you when listers you follow post new pets."
        case .savedSearches: "We'll tell you when new pets match your saved search."
        case .applications: "We'll tell you as soon as the lister updates your application."
        case .messages: "We'll let you know when the lister replies."
        }
    }
}
