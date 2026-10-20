import SwiftUI

/// A basic list of adoptable pets. Phase 2 turns this into the full Discover grid
/// with photos, search, and filters.
struct PetListView: View {
    @State private var viewModel: PetListViewModel

    init(repository: PetRepository) {
        _viewModel = State(initialValue: PetListViewModel(repository: repository))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Finding pets...")
            case .empty:
                EmptyStateView(icon: "pawprint", title: "No pets found", message: "Try again later.")
            case .error(let message):
                ErrorView(message: message) {
                    Task { await viewModel.load() }
                }
            case .loaded:
                list
            }
        }
        .task {
            if viewModel.pets.isEmpty { await viewModel.load() }
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.pets) { pet in
                NavigationLink(value: Route.petDetail(id: pet.id)) {
                    PetRow(pet: pet)
                }
                .listRowBackground(Color.pfSurface)
                .task {
                    if pet.id == viewModel.pets.last?.id { await viewModel.loadMore() }
                }
            }
            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.load() }
    }
}

private struct PetRow: View {
    let pet: Pet

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: pet.species == "Cat" ? "cat.fill" : "dog.fill")
                .font(.title2)
                .foregroundStyle(Color.pfBrandPrimary)
                .frame(width: 48, height: 48)
                .background(Color.pfBrandDeep, in: RoundedRectangle(cornerRadius: Radius.medium))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(pet.name)
                    .font(.pfHeadline)
                    .foregroundStyle(Color.pfTextPrimary)
                Text(pet.breed)
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextSecondary)
                Text(pet.summary)
                    .font(.pfCaption)
                    .foregroundStyle(Color.pfTextSecondary)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

#Preview {
    NavigationStack {
        PetListView(repository: MockPetRepository())
            .background(Color.pfBackground)
    }
}
