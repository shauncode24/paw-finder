import SwiftUI

/// The main app button.
struct PFButton: View {
    enum Style { case primary, secondary }

    let title: String
    var style: Style = .primary
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    Text(title)
                }
            }
            .font(.pfHeadline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(style == .primary ? Color.pfSurfaceElevated : Color.pfBrandPrimary)
            .background(style == .primary ? Color.pfBrandPrimary : Color.clear,
                        in: RoundedRectangle(cornerRadius: Radius.medium))
            .overlay {
                if style == .secondary {
                    RoundedRectangle(cornerRadius: Radius.medium)
                        .stroke(Color.pfBrandPrimary, lineWidth: 1)
                }
            }
        }
        .disabled(isLoading)
    }
}

/// A rounded box with the surface color and a thin border.
struct PFCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pfSurface, in: RoundedRectangle(cornerRadius: Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large)
                    .stroke(Color.pfBorder, lineWidth: 1)
            }
    }
}

/// A pill-shaped tag, used for filters (tap to select) or pet attributes.
struct PFChip: View {
    let title: String
    var isSelected = false
    var action: (() -> Void)?

    var body: some View {
        Text(title)
            .font(.subheadline)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .foregroundStyle(isSelected ? Color.pfBrandPrimary : Color.pfTextPrimary)
            .background(isSelected ? Color.pfBrandDeep : Color.pfSurfaceElevated, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.pfBrandLight : Color.pfBorder, lineWidth: 1))
            .onTapGesture { action?() }
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        PFButton(title: "Apply to adopt") {}
        PFButton(title: "Message shelter", style: .secondary) {}
        HStack {
            PFChip(title: "Dog", isSelected: true)
            PFChip(title: "Cat")
        }
        PFCard { Text("Biscuit · Beagle mix") }
    }
    .padding()
    .background(Color.pfBackground)
}
