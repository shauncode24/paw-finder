import SwiftUI

/// The Favorites tab: collection picker at the top, then the saved pets.
/// Swipe to remove, Edit to drag-reorder, pull down to check for status changes.
struct FavoritesView: View {
    @Environment(FavoritesStore.self) private var store
    @Environment(\.petRepository) private var repository

    @State private var selectedCollection: UUID?
    @State private var showNewCollection = false
    @State private var newCollectionName = ""
    @State private var renamingCollection: PetCollection?
    @State private var renameText = ""
    @State private var showComparePicker = false
    @Environment(Router.self) private var router

    private var items: [FavoritePet] { store.favorites(in: selectedCollection) }

    var body: some View {
        VStack(spacing: 0) {
            collectionBar
            content
        }
        .background(Color.pfBackground)
        .toolbar {
            if !items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            if store.favorites.count >= 2 {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Compare") { showComparePicker = true }
                }
            }
        }
        .task { await store.refreshStatuses(using: repository) }
        .sheet(isPresented: $showComparePicker) {
            ComparePickerSheet(favorites: items.count >= 2 ? items : store.favorites) { pets in
                router.push(.compare(pets))
            }
        }
        .alert("New collection", isPresented: $showNewCollection) {
            TextField("Name", text: $newCollectionName)
            Button("Cancel", role: .cancel) { newCollectionName = "" }
            Button("Create") {
                if let collection = store.createCollection(named: newCollectionName) {
                    selectedCollection = collection.id
                }
                newCollectionName = ""
            }
        } message: {
            Text("For example \"Dogs for apartment\" or \"Maybe later\".")
        }
        .alert("Rename collection", isPresented: Binding(
            get: { renamingCollection != nil },
            set: { if !$0 { renamingCollection = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let renamingCollection { store.renameCollection(renamingCollection.id, to: renameText) }
            }
        }
    }

    // MARK: - Collections bar

    private var collectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                PFChip(title: "All (\(store.favorites.count))", isSelected: selectedCollection == nil) {
                    selectedCollection = nil
                }
                ForEach(store.collections) { collection in
                    PFChip(title: "\(collection.name) (\(collection.petIDs.count))",
                           isSelected: selectedCollection == collection.id) {
                        selectedCollection = collection.id
                    }
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") {
                            renameText = collection.name
                            renamingCollection = collection
                        }
                        Button("Delete collection", systemImage: "trash", role: .destructive) {
                            if selectedCollection == collection.id { selectedCollection = nil }
                            store.deleteCollection(collection.id)
                        }
                    }
                }
                PFChip(title: "+ New collection") { showNewCollection = true }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
        }
    }

    // MARK: - List

    @ViewBuilder
    private var content: some View {
        if store.favorites.isEmpty {
            EmptyStateView(icon: "heart", title: "No favorites yet",
                           message: "Tap the heart on any pet to save it here. Saved pets work offline too.")
        } else if items.isEmpty {
            EmptyStateView(icon: "folder", title: "This collection is empty",
                           message: "Add pets to it from their detail page, or long-press a pet in All.")
        } else {
            List {
                ForEach(items) { favorite in
                    NavigationLink(value: Route.petDetail(favorite.pet)) {
                        FavoriteRow(favorite: favorite)
                    }
                    .listRowBackground(Color.pfSurface)
                    .contextMenu { collectionMenu(for: favorite.pet) }
                }
                .onMove { store.move(in: selectedCollection, from: $0, to: $1) }
                .onDelete { offsets in
                    let ids = offsets.map { items[$0].id }
                    if let selectedCollection {
                        store.removeFromCollection(selectedCollection, petIDs: ids)
                    } else {
                        store.remove(petIDs: ids)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .refreshable { await store.refreshStatuses(using: repository, force: true) }
        }
    }

    @ViewBuilder
    private func collectionMenu(for pet: Pet) -> some View {
        if store.collections.isEmpty {
            Button("New collection", systemImage: "plus") { showNewCollection = true }
        } else {
            ForEach(store.collections) { collection in
                Button {
                    store.toggle(petID: pet.id, in: collection.id, pet: pet)
                } label: {
                    if store.isPet(pet.id, in: collection.id) {
                        Label(collection.name, systemImage: "checkmark")
                    } else {
                        Text(collection.name)
                    }
                }
            }
        }
    }
}

/// One saved pet: photo, name, note, and a badge if its status changed.
private struct FavoriteRow: View {
    let favorite: FavoritePet

    var body: some View {
        HStack(spacing: Spacing.md) {
            Color.clear
                .frame(width: 64, height: 64)
                .overlay { PetPhoto(url: favorite.photoURL, species: favorite.pet.species) }
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text(favorite.pet.name)
                        .font(.pfHeadline)
                        .foregroundStyle(Color.pfTextPrimary)
                    if favorite.statusChanged {
                        Circle()
                            .fill(Color.pfBrandPrimary)
                            .frame(width: 8, height: 8)
                            .accessibilityLabel("Status changed")
                    }
                }
                Text(favorite.pet.breed)
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
                    .lineLimit(1)
                if let badge {
                    Text(badge)
                        .font(.pfCaption.weight(.semibold))
                        .foregroundStyle(favorite.isListed ? Color.pfSuccess : Color.pfError)
                }
                if !favorite.note.isEmpty {
                    Text(favorite.note)
                        .font(.pfCaption)
                        .italic()
                        .foregroundStyle(Color.pfTextSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var badge: String? {
        if !favorite.isListed { return "No longer listed" }
        if favorite.pet.isAdopted { return "Adopted" }
        return nil
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
            .navigationTitle("Favorites")
    }
    .environment(FavoritesStore(fileName: "preview-favorites.json"))
    .environment(Router())
}
