# Leftover

Things from SPEC.md that are still left out or simplified, to keep PawFinder a manageable student project. Nothing here is required for the app to work. Pick items up later if you have time or want to show them off.

Each item notes **what we did instead** and **how to add it later**. Items that have been picked up since are listed at the bottom under **Done in the scope bump**.

**Ground rules for now:** no server in the middle and no tests. Items that need either are marked *(server)* or *(tests)*.

---

## Phase 0: Foundation & Tooling

| Left out | What we did instead | How to add it later |
|---|---|---|
| Swift Package modules (Core, DesignSystem, Domain, Data, Features…) | One app target, code grouped by folder | Move a folder (e.g. `DesignSystem/`) into a local Swift package once the project gets big |
| `.xcconfig` secrets handling | `Config/Secrets.plist` (gitignored), read by `Secrets.swift` | Only worth it if you need different keys for Debug and Release builds |
| Dependency container (`AppEnvironment`) | Each service goes in through `.environment(...)` | Group services into one struct if the list keeps growing |
| Feature flags / remote config | None | Firebase Remote Config, or a simple `enum FeatureFlag` with `UserDefaults` toggles |
| SwiftLint / SwiftFormat | None | `brew install swiftlint`, add a `.swiftlint.yml` and a Run Script build phase |
| GitHub Actions CI *(tests)* | None | Add `.github/workflows/ci.yml` that runs `xcodebuild build test` on `macos-15` |
| Branch strategy doc | Not written down | Follow SPEC §14: `feature/<phase>-<name>`, one PR per feature |
| Universal links (`https://pawfinder.app/pet/123`) | Custom-scheme deep links only (`pawfinder://pet/123`) | Needs a domain you own + Associated Domains (Phase 14) |
| One app-wide error type (`AppError`) with recovery actions | `APIError` and `LocationService.LocationError`, each with user-friendly messages | Merge them if more error sources appear |
| Swift 6 strict concurrency | Swift 5 language mode | Set `SWIFT_VERSION = 6.0` and fix the warnings |
| String Catalogs / localization | Plain English strings | Add `Localizable.xcstrings`; Xcode extracts strings automatically (Phase 15) |
| More button variants (tertiary, destructive) | `PFButton` has primary and secondary; destructive actions use `Button(role: .destructive)` | Add when a screen needs them |
| Tests (unit, UI, snapshot) *(tests)* | None, no test targets | File › New › Target › Unit Testing Bundle; start with `PetFilters.queryItems` and `PetfinderAnimal.toPet()` |
| ADRs (`docs/adr`) | None | Write short notes for big decisions (backend, ML approach) |

## Phase 1: Networking & Data Layer

| Left out | What we did instead | How to add it later |
|---|---|---|
| **API proxy so the secret never ships in the app** *(server)* | Petfinder key and secret are in `Secrets.plist`, **bundled inside the app** | A Firebase Cloud Function that holds the secret and forwards `/animals` requests; point `PetfinderClient` at it |
| Generic `APIClient` with typed `Endpoint`s and interceptors | `PetfinderClient` built just for Petfinder | Only needed if you add a second API (e.g. RescueGroups) |
| ETag / HTTP caching for API responses | Only the first page of each search is saved (for offline) | Use `URLCache` with the request's `cachePolicy` |
| Full Core Data offline store (cache-then-network, staleness policy) | `PetCache` saves the first page of each search as a JSON file; shown only when offline, with a banner | Core Data/SwiftData if you need to query cached pets |
| Generic pagination abstraction (cursor/page) | Simple `PetPage` with page numbers | Fine as is unless another API uses cursors |
| DTO fixtures (saved JSON samples) *(tests)* | `MockPetRepository` with generated pets | Save a real `/animals` response as `animals.json` |
| RescueGroups as an alternative provider | Petfinder only | Second repository that implements `PetRepository` |

## Phase 2: Discovery Core

| Left out | What we did instead | How to add it later |
|---|---|---|
| Custom image pipeline (downsampling, own memory/disk cache) | `AsyncImage` + a bigger `URLCache`; cards use Petfinder's small "medium" photo | Custom `ImageLoader` actor with `NSCache` + `CGImageSourceCreateThumbnailAtIndex` |
| Image prefetching | Photos load when a card appears | `ImageLoader.prefetch(urls)` for the next few cards |
| Color filter | Coat, special needs, and time listed were added; color was not (colors differ per species) | Load colors from Petfinder's `/types/{type}`, show them once a species is picked |
| Recently viewed in Core Data | `UserDefaults` (last 10). Opening one refreshes its data | Fine as is |
| Breed suggestions for every species | Uses the selected species, or dogs + cats if none is selected | Load all types from `/types` |
| Search across descriptions/tags | Name search only (Petfinder's `name` parameter) | Natural-language search is Phase 12 |
| Analytics events | `os.Logger` logs only | Firebase Analytics `logEvent` once Firebase is added |

## Phase 3: Pet Detail

| Left out | What we did instead | How to add it later |
|---|---|---|
| Universal link for sharing *(needs a domain)* | `ShareLink` shares the Petfinder listing URL (or a text message for mock pets) | Phase 14 |
| Full description | Petfinder's API only returns a short preview; "Read more" plus "View full listing on Petfinder" | No fix; this is a Petfinder limitation |
| Actions: apply, message shelter | Not on the detail screen yet | Phase 9 (apply), Phase 10 (message) |
| Compatibility score with your lifestyle | Not shown | Phase 12 (needs the lifestyle questionnaire from Phase 7) |
| Report listing sent to a moderator *(server)* | Saved on the device only (`UserDefaults` key `listingReports`) | Write to a Firestore `reports` collection once Firebase is added |
| Momentum when dragging a zoomed photo | Drag stops when your finger lifts | Animate the offset with the drag's predicted end |

## Phase 4: Favorites, Collections & Offline

| Left out | What we did instead | How to add it later |
|---|---|---|
| Core Data storage | One JSON file (`Documents/favorites.json`) plus saved photos in `Documents/FavoritePhotos/` | SwiftData/Core Data if the data gets large or needs queries |
| Outbox for offline changes *(server)* | Not needed yet: favorites only live on the device | Add with cloud sync (Phase 8) |
| Push notifications *(server)* | **Local** notifications from the background check | Phase 11 |
| "Pending" status | Petfinder only reports adoptable/adopted/found | No fix; this is a Petfinder limitation |
| Reordering inside a collection from the detail screen | Reorder from the Favorites tab (Edit button) | Fine as is |
| Tests for the store *(tests)* | None | Test `FavoritesStore` with a temporary `fileName` |

## Phase 5: Location, Map & Shelters

| Left out | What we did instead | How to add it later |
|---|---|---|
| Continuous location updates (`AsyncStream`) | `LocationService` gets the location once when asked; the map's blue dot (`UserAnnotation`) tracks you by itself | Wrap `CLLocationUpdate.liveUpdates()` if a feature needs live tracking |
| MapKit's built-in clustering | A simple grid clustering (`ShelterCluster.make`) that regroups when the map stops moving | `MKMapView` in a `UIViewRepresentable` with `clusteringIdentifier` |
| Exact shelter coordinates | Petfinder doesn't send coordinates, so addresses are looked up with Apple's geocoder (saved to disk). Pins appear gradually; a shelter whose address can't be found has no pin (it's still in the list view) | No fix without coordinates from the API |
| Big result pages | 25 shelters per search ("Load more" in the list view), because each needs geocoding and Apple limits lookups to ~50/min | Fine as is |
| Filter shelters by which animals they have | Chips for distance, "Open now", and "Following" | Petfinder doesn't say which species a shelter has without fetching its pets |
| Volunteer and donation links | Website, adoption policy, and Petfinder page links | Petfinder doesn't provide these; show the shelter's social links (`social_media` in the API) |
| Shelter photo gallery | First photo as the header | Reuse `PhotoCarousel` |
| Accurate "open now" | Best-effort reading of the free-text hours ("9-5", "10am-6pm", "Closed"), using the phone's time zone | Unreadable hours show nothing rather than a wrong answer |
| Push notifications for new arrivals *(server)* | Local notifications from the background check (iOS decides when it runs) | Phase 11 |
| Geofencing (optional in SPEC) | None | `CLMonitor` with a region around followed shelters |
| Offline shelter search | Shelter results aren't cached (shelter profiles and coordinates are) | Save the last results like `PetCache` |
| Mock data respects the searched location | Sample data always returns all 8 shelters; the map zooms out to fit them | Fine for testing |

## Later phases (6 onwards)

Not started yet. When a phase is built, anything left out or simplified gets added here under that phase's heading.

---

## Done in the scope bump

These were on this list and are now in the app:

| Item | Where |
|---|---|
| `os.Logger` logging instead of `print` | `App/Log.swift` (`Log.network`, `Log.storage`, ...) |
| Deep links: `pawfinder://pet/123`, `pawfinder://favorites`, `pawfinder://settings` | `Router.handle(_:)`, `Route.petID` + `PetLoaderView`, URL scheme in `Info.plist` |
| Light/dark/system appearance setting | Profile › Settings (`SettingsView`, `@AppStorage("appearance")`) |
| `@ScaledMetric` empty-state icons | `EmptyStateView` |
| Retry with backoff on 429/5xx | `PetfinderClient.sendWithRetry` (waits 1s, then 2s) |
| Offline results for Discover | `PetCache` + "You're offline" banner |
| Grid / list layout toggle | Discover toolbar (remembered) |
| Shimmer on loading placeholders (off with Reduce Motion) | `PetCard.swift` → `.shimmering()` |
| Coat, special needs, and "time listed" filters | `PetFilters`, `FilterSheet` |
| "Use my current location" | `LocationService`, `FilterSheet` |
| Real "New today" rail (falls back to "Just added"); rails follow your location | `DiscoverViewModel.loadRailsIfNeeded` |
| "Couldn't load more · Retry" row | Discover |
| Pet videos | `PetVideoView` (WKWebView) on the detail screen |
| Distance from **your** location to the shelter | `ShelterCard` (uses `LocationService.lastLocation`) |
| Get directions | `ShelterCard` → Apple Maps driving directions |
| Zoomed photo can't be dragged off screen | `PhotoCarousel` → `ZoomableImage.clamped` |
| Refresh pet data when the detail opens (also updates the saved favorite) | `PetDetailViewModel.refreshPet` |
| Shelter + map location cache | `PetDetailViewModel.shelterCache` / `coordinateCache` |
| Spotlight search of favorites | `SpotlightIndexer` |
| Notification when a favorite is adopted/removed | `NotificationManager` (local notifications) |
| Background check of favorites | `BackgroundRefresh` + `.backgroundTask(.appRefresh)` in `PawFinderApp` |
| Offline photos for favorites | `FavoritesStore.savePhoto` |

---

**Not yet verified:** Phases 0–5 and the scope bump were written without building in Xcode (the code was written on Windows). The first build on a Mac may surface small compile errors.
