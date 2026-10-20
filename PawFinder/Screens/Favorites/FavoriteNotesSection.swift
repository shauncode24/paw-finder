import SwiftUI

/// On the detail screen of a favorited pet: a personal note and collection chips.
struct FavoriteNotesSection: View {
    let pet: Pet
    @Environment(FavoritesStore.self) private var favorites
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("My notes")
                .font(.pfTitle)
                .foregroundStyle(Color.pfTextPrimary)

            TextField("e.g. Ask about crate training", text: $note, axis: .vertical)
                .lineLimit(2...5)
                .padding(Spacing.md)
                .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))
                .onChange(of: note) { _, newValue in
                    favorites.setNote(newValue, for: pet.id)
                }

            if !favorites.collections.isEmpty {
                Text("Collections")
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                    .padding(.top, Spacing.sm)
                FlowLayout {
                    ForEach(favorites.collections) { collection in
                        PFChip(title: collection.name, isSelected: favorites.isPet(pet.id, in: collection.id)) {
                            favorites.toggle(petID: pet.id, in: collection.id, pet: pet)
                        }
                    }
                }
            } else {
                Text("Make collections in the Favorites tab to group pets.")
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
            }
        }
        .onAppear {
            note = favorites.favorite(for: pet.id)?.note ?? ""
        }
    }
}
