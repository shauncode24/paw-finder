import SwiftUI

/// A pet's photo, or a paw placeholder while loading / when there's no photo.
/// Photos are loaded and cached by `PhotoLoader`.
struct PetPhoto: View {
    let url: URL?
    var species = "Dog"

    var body: some View {
        RemoteImage(url: url) { phase in
            if case .success(let image) = phase {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.pfBrandDeep
                    Image(systemName: species == "Cat" ? "cat.fill" : "pawprint.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.pfBrandLight)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A grid cell: photo on top, name and details below.
struct PetCard: View {
    let pet: Pet
    var showsFavoriteButton = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed-height box so every photo is cropped to the same shape.
            Color.clear
                .frame(height: 150)
                .overlay { PetPhoto(url: pet.thumbnailURL, species: pet.species) }
                .clipped()
                .overlay(alignment: .topTrailing) {
                    if showsFavoriteButton {
                        FavoriteButton(pet: pet, style: .overlay)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if pet.needsFoster { FosterBadge().padding(Spacing.sm) }
                }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(pet.name)
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                    .lineLimit(1)
                Text(pet.breed)
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
                    .lineLimit(1)
                Text(locationText)
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
                    .lineLimit(1)
            }
            .padding(Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pfSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large)
                .stroke(Color.pfBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var locationText: String {
        if let distance = pet.distance {
            return "\(pet.location) · \(Int(distance.rounded())) mi"
        }
        return pet.location
    }
}

/// "Needs a foster" tag on a pet's card.
struct FosterBadge: View {
    var body: some View {
        Label("Needs a foster", systemImage: "house.and.flag.fill")
            .font(.pfCaption.weight(.semibold))
            .foregroundStyle(Color.pfSurfaceElevated)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 3)
            .background(Color.pfBrandPrimary, in: Capsule())
    }
}

/// A list row: small photo on the left, details on the right (list layout).
struct PetRow: View {
    let pet: Pet
    var showsFavoriteButton = true

    var body: some View {
        HStack(spacing: Spacing.md) {
            Color.clear
                .frame(width: 72, height: 72)
                .overlay { PetPhoto(url: pet.thumbnailURL, species: pet.species) }
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(pet.name)
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                Text(pet.breed)
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
                    .lineLimit(1)
                Text(pet.summary)
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
                if pet.needsFoster { FosterBadge() }
            }
            Spacer(minLength: 0)
            if showsFavoriteButton {
                FavoriteButton(pet: pet)
            }
        }
        .padding(Spacing.sm)
        .background(Color.pfSurface, in: RoundedRectangle(cornerRadius: Radius.large))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large)
                .stroke(Color.pfBorder, lineWidth: 1)
        }
    }
}

/// Grey placeholder card shown while the first page loads.
struct SkeletonPetCard: View {
    var body: some View {
        PetCard(pet: Pet.placeholder, showsFavoriteButton: false)
            .redacted(reason: .placeholder)
            .shimmering()
            .accessibilityLabel("Loading")
    }
}

/// Grey placeholder row for the list layout.
struct SkeletonPetRow: View {
    var body: some View {
        PetRow(pet: Pet.placeholder, showsFavoriteButton: false)
            .redacted(reason: .placeholder)
            .shimmering()
            .accessibilityLabel("Loading")
    }
}

/// A soft light band that sweeps across loading placeholders.
/// Turned off when the user has Reduce Motion on.
private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, Color.pfSurfaceElevated.opacity(0.6), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: phase * proxy.size.width * 1.6)
                    }
                    .clipped()
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

/// A titled, horizontally scrolling row of small pet cards.
struct PetRail: View {
    let title: String
    let pets: [Pet]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.pfHeadline)
                .foregroundStyle(Color.pfTextPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.md) {
                    ForEach(pets) { pet in
                        NavigationLink(value: Route.petDetail(pet)) {
                            PetCard(pet: pet)
                                .frame(width: 150)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

#Preview {
    HStack {
        PetCard(pet: MockPetRepository.samplePets[0])
        SkeletonPetCard()
    }
    .padding()
    .background(Color.pfBackground)
    .environment(FavoritesStore(fileName: "preview-favorites.json"))
}
