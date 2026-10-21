import SwiftUI

/// The Discover tab: search bar, filter button, curated rails, and the pet grid.
struct DiscoverView: View {
    @State private var viewModel: DiscoverViewModel
    @State private var showFilters = false
    @AppStorage("discoverShowsList") private var showsList = false
    @Environment(RecentlyViewedStore.self) private var recentlyViewed
    @Environment(SavedSearchesStore.self) private var savedSearches
    @Environment(Router.self) private var router
    @State private var showSaveSearch = false
    @State private var saveSearchName = ""

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: Spacing.md)]

    init(repository: PetRepository) {
        _viewModel = State(initialValue: DiscoverViewModel(repository: repository))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if let cachedAt = viewModel.cachedAt {
                    offlineBanner(cachedAt)
                } else if viewModel.isShowingSamples {
                    sampleBanner
                }

                if viewModel.filters.isBrowsing {
                    DiscoverHeader(filters: viewModel.filters, pool: viewModel.newestPets + viewModel.pets)
                }

                activeFilterChips

                if viewModel.filters.isBrowsing {
                    rails
                }

                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(viewModel.filters.isBrowsing ? "All pets" : "Results")
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
            ToolbarItem(placement: .topBarLeading) { savedSearchMenu }
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(value: Route.swipe(viewModel.filters)) {
                    Image(systemName: "rectangle.stack")
                }
                .accessibilityLabel("Swipe mode")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { showsList.toggle() }
                } label: {
                    Image(systemName: showsList ? "square.grid.2x2" : "list.bullet")
                }
                .accessibilityLabel(showsList ? "Show as grid" : "Show as list")
            }
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
        .task(id: viewModel.filters.location) { await viewModel.loadRailsIfNeeded() }
        // Run a saved search picked from the list or a notification.
        // Filters from Siri, breed guides, or links.
        .onChange(of: router.pendingFilters, initial: true) { _, filters in
            guard let filters else { return }
            viewModel.filters = filters
            router.pendingFilters = nil
        }
        .onChange(of: router.pendingSavedSearchID, initial: true) { _, id in
            guard let id else { return }
            if let search = savedSearches.search(id) {
                viewModel.filters = search.filters
                savedSearches.markSeen(id)
            }
            router.pendingSavedSearchID = nil
        }
        .alert("Save this search", isPresented: $showSaveSearch) {
            TextField("Name", text: $saveSearchName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                savedSearches.add(name: saveSearchName, filters: viewModel.filters, alertsOn: true)
                Task { await NotificationManager.shared.askPermission(for: .savedSearches) }
            }
        } message: {
            Text("We'll let you know when new pets match.")
        }
    }

    // MARK: - Saved searches

    private var savedSearchMenu: some View {
        let current = savedSearches.search(matching: viewModel.filters)
        return Menu {
            if let current {
                Button("Remove from saved", systemImage: "bookmark.slash") { savedSearches.delete(current.id) }
            } else {
                Button("Save this search", systemImage: "bookmark") {
                    saveSearchName = SavedSearch.suggestedName(for: viewModel.filters)
                    showSaveSearch = true
                }
                .disabled(viewModel.filters.isDefault)
            }
            NavigationLink(value: Route.savedSearches) {
                Label("Saved searches (\(savedSearches.searches.count))", systemImage: "list.bullet")
            }
        } label: {
            Image(systemName: current == nil ? "bookmark" : "bookmark.fill")
                .overlay(alignment: .topTrailing) {
                    if savedSearches.newMatchTotal > 0 {
                        Circle().fill(Color.pfBrandPrimary).frame(width: 8, height: 8).offset(x: 4, y: -2)
                    }
                }
        }
        .accessibilityLabel("Saved searches")
        .accessibilityValue(savedSearches.newMatchTotal > 0 ? "\(savedSearches.newMatchTotal) new matches" : "")
    }

    // MARK: - Sections

    @ViewBuilder
    private var results: some View {
        switch viewModel.state {
        case .loading:
            if showsList {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(0..<6, id: \.self) { _ in SkeletonPetRow() }
                }
            } else {
                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    ForEach(0..<6, id: \.self) { _ in SkeletonPetCard() }
                }
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
            if showsList {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(viewModel.pets) { pet in
                        petLink(pet) { PetRow(pet: pet) }
                    }
                }
            } else {
                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    ForEach(viewModel.pets) { pet in
                        petLink(pet) { PetCard(pet: pet) }
                    }
                }
            }
            if viewModel.isLoadingMore {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.loadMoreFailed {
                HStack {
                    Text("Couldn't load more pets.")
                        .foregroundStyle(Color.pfTextSecondary)
                    Button("Retry") { Task { await viewModel.loadMore() } }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Opens the pet, and loads the next page when the last one appears.
    private func petLink(_ pet: Pet, @ViewBuilder label: () -> some View) -> some View {
        NavigationLink(value: Route.petDetail(pet)) {
            label()
        }
        .buttonStyle(.plain)
        .onAppear {
            if pet.id == viewModel.pets.last?.id {
                Task { await viewModel.loadMore() }
            }
        }
    }

    private var sampleBanner: some View {
        Label(Secrets.hasPetfinderKeys
              ? "Petfinder isn't reachable right now, so you're seeing sample pets."
              : "You're seeing sample pets. Add Petfinder keys to see real adoptable pets.",
              systemImage: "sparkles")
            .font(.subheadline)
            .foregroundStyle(Color.pfTextPrimary)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pfBrandDeep, in: RoundedRectangle(cornerRadius: Radius.medium))
    }

    private func offlineBanner(_ date: Date) -> some View {
        Label("You're offline. Showing pets saved \(date.formatted(.relative(presentation: .named))).",
              systemImage: "wifi.slash")
            .font(.subheadline)
            .foregroundStyle(Color.pfTextPrimary)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pfBrandDeep, in: RoundedRectangle(cornerRadius: Radius.medium))
    }

    @ViewBuilder
    private var rails: some View {
        if !recentlyViewed.pets.isEmpty {
            PetRail(title: "Recently viewed", pets: recentlyViewed.pets)
        }
        if !viewModel.newestPets.isEmpty {
            PetRail(title: viewModel.newestTitle, pets: viewModel.newestPets)
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
        if filters.specialNeeds { chips.append(("Special needs", { $0.specialNeeds = false })) }
        for coat in PetFilters.Coat.allCases where filters.coats.contains(coat) {
            chips.append(("\(coat.rawValue) coat", { $0.coats.remove(coat) }))
        }
        if filters.listed != .any {
            chips.append((filters.listed.rawValue, { $0.listed = .any }))
        }
        if !filters.location.isEmpty {
            chips.append(("Within \(filters.distance) mi of \(filters.locationLabel)", {
                $0.location = ""
                $0.locationName = nil
            }))
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
    .environment(FavoritesStore(fileName: "preview-favorites.json"))
    .environment(LocationService())
    .environment(FollowedSheltersStore())
    .environment(AuthManager())
    .environment(ProfileStore())
    .environment(ApplicationsStore())
    .environment(MessagesStore())
    .environment(SavedSearchesStore())
    .environment(Router())
}
