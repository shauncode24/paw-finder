import SwiftUI

/// Heart that favorites / unfavorites a pet, with a bounce and a haptic tap.
struct FavoriteButton: View {
    enum Style {
        case toolbar   // plain icon, for the navigation bar
        case overlay   // icon in a round background, for photos
    }

    let pet: Pet
    var style: Style = .toolbar
    @Environment(FavoritesStore.self) private var favorites

    var body: some View {
        let isFavorite = favorites.isFavorite(pet.id)

        Button {
            favorites.toggle(pet)
            if favorites.isFavorite(pet.id) {
                // First favorite is a good moment to ask: we'll tell them if this pet gets adopted.
                Task { await NotificationManager.shared.requestAuthorizationIfNeeded() }
            }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? Color.pfBrandPrimary : (style == .overlay ? Color.pfTextPrimary : Color.pfBrandPrimary))
                .symbolEffect(.bounce, value: isFavorite)
                .font(style == .overlay ? .body.weight(.semibold) : .body)
                .frame(width: 36, height: 36)
                .background {
                    if style == .overlay {
                        Circle().fill(Color.pfSurfaceElevated.opacity(0.9))
                    }
                }
                .frame(width: 44, height: 44)   // bigger tap area than it looks
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isFavorite)
        .accessibilityLabel(isFavorite ? "Remove \(pet.name) from favorites" : "Add \(pet.name) to favorites")
    }
}

#Preview {
    HStack {
        FavoriteButton(pet: MockPetRepository.samplePets[0])
        FavoriteButton(pet: MockPetRepository.samplePets[1], style: .overlay)
    }
    .padding()
    .background(Color.pfBrandDeep)
    .environment(FavoritesStore(fileName: "preview-favorites.json"))
}
