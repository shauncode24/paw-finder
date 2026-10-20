import SwiftUI

/// The Discover tab: search bar, filter button, curated rails, and the pet grid.
struct DiscoverView: View {
    @State private var viewModel: DiscoverViewModel
    @State private var showFilters = false
    @Environment(RecentlyViewedStore.self) private var recentlyViewed

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: Spacing.md)]

    init(repository: PetRepository) {
        _viewModel = State(initialValue: DiscoverViewModel(repository: repository))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                activeFilterChips

                if viewModel.filters.isDefault {
                    rails
                }

                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(viewModel.filters.isDefault ? "All pets" : "Results")
                        .font(.pfTitle)
                        .foregroundStyle(Color.pfTextPrimary)
                    results
                }
            }
            .padding(Spacing.lg)
        }
        .background(Color.pfBackground)
        .searchable(text: $viewModel.filters.name, prompt: "Search by name or breed")
        .searchSuggestions {
            ForEach(viewModel.breedSuggestions, id: \.self) { breed in
                Button {
                    viewModel.selectBreed(breed)
                } label: {
                    Label(breed, systemImage: "pawprint")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: viewModel.filters.activeCount > 0
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filters")
                .accessibilityValue(viewModel.filters.activeCount > 0 ? "\(viewModel.filters.activeCount) active" : "")
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet(filters: viewModel.filters) { viewModel.applyFilters($0) }
        }
        .refreshable { await viewModel.reload() }
        .task(id: viewModel.filters) { await viewModel.filtersChanged() }
        .task(id: viewModel.filters.species) { await viewModel.loadBreeds() }
        .task { await viewModel.loadRailsIfNeeded() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var results: some View {
        switch viewModel.state {
        case .loading:
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(0..<6, id: \.self) { _ in SkeletonPetCard() }
            }
        case .empty:
            EmptyStateView(icon: "magnifyingglass", title: "No matches",
                           message: "Try removing some filters.",
                           buttonTitle: "Clear filters") { viewModel.clearFilters() }
                .frame(minHeight: 300)
        case .error(let message):
            ErrorView(message: message) {
                Task { await viewModel.reload(showSkeleton: true) }
            }
            .frame(minHeight: 300)
        case .loaded:
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(viewModel.pets) { pet in
                    NavigationLink(value: Route.petDetail(pet)) {
                        PetCard(pet: pet)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if pet.id == viewModel.pets.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }
            }
            if viewModel.isLoadingMore {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var rails: some View {
        if !recentlyViewed.pets.isEmpty {
            PetRail(title: "Recently viewed", pets: recentlyViewed.pets)
        }
        if !viewModel.newestPets.isEmpty {
            PetRail(title: "Just added", pets: viewModel.newestPets)
        }
        if !viewModel.longestWaitingPets.isEmpty {
            PetRail(title: "Longest waiting", pets: viewModel.longestWaitingPets)
        }
    }

    /// One removable chip per active filter.
    @ViewBuilder
    private var activeFilterChips: some View {
        let chips = activeChips
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(chips, id: \.title) { chip in
                        PFChip(title: "\(chip.title)  ✕", isSelected: true) {
                            var updated = viewModel.filters
                            chip.remove(&updated)
                            viewModel.filters = updated
                        }
                        .accessibilityLabel("Remove filter \(chip.title)")
                    }
                    if chips.count > 1 {
                        Button("Clear all") { viewModel.clearFilters() }
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private var activeChips: [(title: String, remove: (inout PetFilters) -> Void)] {
        let filters = viewModel.filters
        var chips: [(title: String, remove: (inout PetFilters) -> Void)] = []
        if let species = filters.species {
            chips.append((species.rawValue, { $0.species = nil; $0.breed = nil }))
        }
        if let breed = filters.breed {
            chips.append((breed, { $0.breed = nil }))
        }
        for age in PetFilters.Age.allCases where filters.ages.contains(age) {
            chips.append((age.rawValue, { $0.ages.remove(age) }))
        }
        for size in PetFilters.Size.allCases where filters.sizes.contains(size) {
            chips.append((size.rawValue, { $0.sizes.remove(size) }))
        }
        if let gender = filters.gender {
            chips.append((gender.rawValue, { $0.gender = nil }))
        }
        if filters.goodWithKids { chips.append(("Good with kids", { $0.goodWithKids = false })) }
        if filters.goodWithDogs { chips.append(("Good with dogs", { $0.goodWithDogs = false })) }
        if filters.goodWithCats { chips.append(("Good with cats", { $0.goodWithCats = false })) }
        if filters.houseTrained { chips.append(("House-trained", { $0.houseTrained = false })) }
        if !filters.location.isEmpty {
            chips.append(("Within \(filters.distance) mi of \(filters.location)", { $0.location = "" }))
        }
        return chips
    }
}

#Preview {
    NavigationStack {
        DiscoverView(repository: MockPetRepository())
            .navigationTitle("Discover")
            .navigationDestination(for: Route.self) { RouteView(route: $0) }
    }
    .environment(RecentlyViewedStore())
}
