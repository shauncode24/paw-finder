# PawFinder

Native iOS (SwiftUI) pet adoption app, built as a student project. Feature list and phase plan: @docs/SPEC.md. Colors (light and dark): @docs/DESIGN.md. Setup: @docs/SETUP.md. Things deliberately left out: @docs/Leftover.md.

**Keep it simple.** This is not production-grade. Prefer the simplest thing that works. SPEC.md, ARCHITECTURE.md, and CONVENTIONS.md describe a bigger, modular setup; use them for *what* to build, not for how much infrastructure to add.

## Current phase
Phase 4 done (update this line as phases complete)

## Setup
- One Xcode project, one app target, no Swift packages. Group code by folder: `App/`, `Screens/`, `DesignSystem/`, `Config/`, `Models/`, `Services/`.
- The Xcode project uses folder-synchronized groups, so new files in `PawFinder/` are picked up automatically.
- iOS 17+, SwiftUI, `@Observable` view models, async/await. Swift 5 language mode.
- Navigation: `Router` (selected tab + a `[Route]` path per tab). Add `Route` cases for new screens.
- Keys live in `PawFinder/Config/Secrets.plist` (gitignored) and are read through `Secrets`.
- Data: screens use the `PetRepository` protocol (from `@Environment(\.petRepository)`). `RemotePetRepository` calls Petfinder through `PetfinderClient` (an actor that handles the OAuth token); `MockPetRepository` is used when no keys are set and in previews. JSON shapes live in `PetfinderModels.swift` and are converted to `Pet` with `toPet()`.
- Screen pattern: an `@Observable` view model with a `State` enum (loading / loaded / empty / error). See `Screens/Discover/DiscoverView` + `DiscoverViewModel`.
- Discover: search and filters live in one `PetFilters` value (saved to UserDefaults, minus search text) that maps to Petfinder query params. The view reloads via `.task(id: filters)` with a short debounce. `PetCard`, `PetPhoto` (AsyncImage + bigger `URLCache`), and `PetRail` are reusable.
- `Route.petDetail(Pet)` carries the whole pet. `RecentlyViewedStore` (environment) records opened pets.
- Pet detail (`Screens/PetDetail/`): `PetDetailView` + `PetDetailViewModel` (loads `Shelter` via `fetchShelter`, geocodes its address with `CLGeocoder`, and finds similar pets). `PhotoCarousel` has the full-screen zoom viewer; `ShelterCard` has the mini-map and contact links. `FlowLayout` (DesignSystem) wraps chips.
- Favorites (`Screens/Favorites/`): `FavoritesStore` (environment, `@MainActor @Observable`) saves `FavoritePet` snapshots + `PetCollection`s to `Documents/favorites.json`. `FavoriteButton` is the animated heart (on `PetCard` and the detail toolbar). `refreshStatuses(using:)` re-fetches favorites to detect adopted/removed pets. Mock pet `mock-5` "gets adopted" on refresh to demo this.
- No Core Data or unit tests yet; add them only if a phase really needs them.
- Firebase goes in when a phase needs it (via Swift Package Manager in Xcode).

## Rules
- Build only the current phase.
- Whenever a phase leaves out or simplifies something from SPEC.md, add it to docs/Leftover.md under that phase (what we did instead, how to add it later).
- Use the `Color.pf*` colors, `Spacing`, `Radius`, and `PF*` components from `DesignSystem/`; no raw colors.
- Screens should handle loading, empty, and error states (`LoadingView`, `EmptyStateView`, `ErrorView`).
- Avoid force-unwraps.
- Never commit keys.
- Ask before adding dependencies.
- Don't run git commands; the user handles git.
