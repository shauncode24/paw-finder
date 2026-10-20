import SwiftUI

/// A pet's photo, or a paw placeholder while loading / when there's no photo.
/// Images are cached by URLCache (set up in PawFinderApp).
struct PetPhoto: View {
    let url: URL?
    var species = "Dog"

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
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

/// Grey placeholder card shown while the first page loads.
struct SkeletonPetCard: View {
    var body: some View {
        PetCard(pet: MockPetRepository.samplePets[0], showsFavoriteButton: false)
            .redacted(reason: .placeholder)
            .accessibilityLabel("Loading")
    }
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
