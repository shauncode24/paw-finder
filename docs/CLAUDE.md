# PawFinder

Native iOS (SwiftUI) pet adoption app, built as a student project. Feature list and phase plan: @docs/SPEC.md. Colors (light and dark): @docs/DESIGN.md. Setup: @docs/SETUP.md. Things deliberately left out: @docs/Leftover.md.

**Keep it simple.** This is not production-grade. Prefer the simplest thing that works. SPEC.md, ARCHITECTURE.md, and CONVENTIONS.md describe a bigger, modular setup; use them for *what* to build, not for how much infrastructure to add.

## Current phase
Phase 10 done; Phases 6 (Core ML) and 8 (cloud sync) skipped for now (update this line as phases complete)

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
- Firebase: the `firebase-ios-sdk` Swift package is in the project with only **FirebaseAuth** linked. Add more products (Firestore, Storage) to the target when a phase needs them. `AuthManager.configureFirebase()` only configures if `GoogleService-Info.plist` is present; otherwise the app runs guest-only.
- Extra Info.plist keys (URL scheme `pawfinder`, background fetch, BG task ID) live in the root `Info.plist`, merged with the generated one. Simple keys like permission texts go in build settings (`INFOPLIST_KEY_...`) in the project.
- Logging: use `Log.app/network/storage/location/notifications` (os.Logger), not `print`.
- Deep links: `Router.handle(url)` (`pawfinder://pet/<id>`, `pawfinder://<tab>`, `pawfinder://settings`). `Route.petID` → `PetLoaderView` (uses the saved favorite first).
- Services in the environment: `Router`, `RecentlyViewedStore`, `FavoritesStore`, `LocationService`, `\.petRepository`. `NotificationManager.shared` (local notifications), `SpotlightIndexer`, `BackgroundRefresh`, `PetCache` (offline first page per search).
- Shelters (`Screens/Map/`, `Screens/Shelters/`): `ShelterMapView` + `ShelterMapViewModel` (search by GPS/ZIP/"Search this area", grid clustering via `ShelterCluster`, list mode). `ShelterProfileView` (`Route.shelter(id:)`). `ShelterGeocoder.shared` turns addresses into coordinates with a disk cache (Petfinder has no coordinates). `FollowedSheltersStore` (environment) + background check for new arrivals. Reusable: `ShelterMiniMap`, `ContactButtons`, `OpenStatusLabel`, `MapsLink`. `Shelter.openStatus()` reads free-text hours.
- Accounts (`Screens/Account/`, `Screens/Onboarding/`): `AuthManager` (environment) wraps Firebase Auth: email **or username** + password (usernames map to `<name>@users.pawfinder.app`) and Sign in with Apple (capability off until there's a paid account). `ProfileStore` (environment) keeps one `AdopterProfile` (name, lifestyle answers) + avatar per user on the device, and moves the guest profile to the account on first sign-in. `OnboardingView` shows once (`@AppStorage("hasCompletedOnboarding")`). `AccountView` has sign out, export (`DataExporter`), and delete (re-auth first).
- Applications (`Screens/Applications/`): `ApplicationsStore` (environment) saves `AdoptionApplication`s to `Documents/applications.json` (attachments in `Documents/ApplicationFiles/<id>/`). Drafts autosave. A **simulated shelter** plans status replies on submit (`scheduledEvents`), applied by `refresh()` (on launch, foreground, background task, and every 10s on the detail screen); matching local notifications are scheduled by `NotificationManager.scheduleApplicationUpdates`. Routes: `.applications`, `.applicationForm(id)`, `.applicationDetail(id)`; deep link `pawfinder://application/<uuid>`.
- Messages (`Screens/Messages/`): `MessagesStore` (environment) saves `Conversation`s to `Documents/messages.json` (photos in `Documents/MessageFiles/`). A **simulated shelter** plans a keyword-based reply on send (`pendingReplies`), applied by `refresh()`; local notification via `NotificationManager.scheduleMessageReply` (suppressed for the open chat via `openConversationID`). `NetworkMonitor` (environment) drives the offline outbox (`flushOutbox()`). `ContentModerator` checks outgoing text. Unread count badges the Profile tab. Routes `.messages`, `.conversation(id)`; deep link `pawfinder://conversation/<uuid>`.
- For now and later phases: **no server, no cloud, no tests.** Firebase Auth (already in) is the only cloud piece. Anything cloud-related goes to docs/Leftover.md marked *(cloud)*.

## Rules
- Build only the current phase.
- Whenever a phase leaves out or simplifies something from SPEC.md, add it to docs/Leftover.md under that phase (what we did instead, how to add it later).
- Use the `Color.pf*` colors, `Spacing`, `Radius`, and `PF*` components from `DesignSystem/`; no raw colors.
- Screens should handle loading, empty, and error states (`LoadingView`, `EmptyStateView`, `ErrorView`).
- Avoid force-unwraps.
- Never commit keys.
- Ask before adding dependencies.
- Don't run git commands; the user handles git.
