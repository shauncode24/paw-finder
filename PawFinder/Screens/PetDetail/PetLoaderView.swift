import SwiftUI

/// Opens a pet when we only have its ID (deep links, notifications, Spotlight).
/// Uses the saved favorite if there is one (works offline), otherwise downloads it.
struct PetLoaderView: View {
    let petID: String
    @Environment(\.petRepository) private var repository
    @Environment(FavoritesStore.self) private var favorites

    @State private var pet: Pet?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let pet {
                PetDetailView(pet: pet, repository: repository)
            } else if let errorMessage {
                ErrorView(message: errorMessage) { Task { await load() } }
            } else {
                LoadingView(message: "Loading pet...")
            }
        }
        .background(Color.pfBackground)
        .task {
            if pet == nil { await load() }
        }
    }

    private func load() async {
        errorMessage = nil
        if let saved = favorites.favorite(for: petID) {
            pet = saved.pet
            return
        }
        do {
            pet = try await repository.fetchPet(id: petID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
