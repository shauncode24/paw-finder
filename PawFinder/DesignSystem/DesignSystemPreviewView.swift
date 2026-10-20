import SwiftUI

/// Shows all colors and components in one place (Profile > Design system).
/// Handy for checking light and dark mode.
struct DesignSystemPreviewView: View {
    @State private var selected = "Dog"

    private let colors: [(String, Color)] = [
        ("background", .pfBackground), ("surface", .pfSurface), ("surfaceElevated", .pfSurfaceElevated),
        ("brandPrimary", .pfBrandPrimary), ("brandLight", .pfBrandLight), ("brandDeep", .pfBrandDeep),
        ("textPrimary", .pfTextPrimary), ("textSecondary", .pfTextSecondary), ("border", .pfBorder),
        ("error", .pfError), ("success", .pfSuccess),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Colors").font(.pfHeadline)
                ForEach(colors, id: \.0) { name, color in
                    HStack {
                        RoundedRectangle(cornerRadius: Radius.small)
                            .fill(color)
                            .frame(width: 44, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: Radius.small).stroke(Color.pfBorder))
                        Text(name).font(.pfCaption)
                    }
                }

                Text("Buttons").font(.pfHeadline)
                PFButton(title: "Primary") {}
                PFButton(title: "Secondary", style: .secondary) {}
                PFButton(title: "Loading", isLoading: true) {}

                Text("Chips").font(.pfHeadline)
                HStack {
                    ForEach(["Dog", "Cat", "Rabbit"], id: \.self) { option in
                        PFChip(title: option, isSelected: selected == option) { selected = option }
                    }
                }

                Text("Card").font(.pfHeadline)
                PFCard {
                    VStack(alignment: .leading) {
                        Text("Biscuit").font(.pfHeadline)
                        Text("Beagle mix · 2 years").foregroundStyle(Color.pfTextSecondary)
                    }
                }
            }
            .foregroundStyle(Color.pfTextPrimary)
            .padding(Spacing.lg)
        }
        .background(Color.pfBackground)
        .navigationTitle("Design system")
    }
}

#Preview {
    NavigationStack { DesignSystemPreviewView() }
}
