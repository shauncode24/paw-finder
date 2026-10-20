import SwiftUI

/// Shown while something is loading.
struct LoadingView: View {
    var message = "Loading..."

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
            Text(message)
                .font(.pfBody)
                .foregroundStyle(Color.pfTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown when there is nothing to display. The button is optional.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.pfBrandLight)
            Text(title)
                .font(.pfTitle)
                .foregroundStyle(Color.pfTextPrimary)
            Text(message)
                .font(.pfBody)
                .foregroundStyle(Color.pfTextSecondary)
                .multilineTextAlignment(.center)
            if let buttonTitle, let action {
                PFButton(title: buttonTitle, action: action)
                    .frame(maxWidth: 240)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown when something fails, with a retry button.
struct ErrorView: View {
    var message = "Something went wrong."
    let retry: () -> Void

    var body: some View {
        EmptyStateView(icon: "exclamationmark.triangle", title: "Oops", message: message,
                       buttonTitle: "Try again", action: retry)
    }
}

#Preview("Loading") { LoadingView() }
#Preview("Empty") { EmptyStateView(icon: "heart", title: "No favorites yet", message: "Tap the heart on a pet to save it.") }
#Preview("Error") { ErrorView {} }
