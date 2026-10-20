# Leftover

Things from SPEC.md that were left out or simplified to keep PawFinder a manageable student project. Nothing here is required for the app to work. Pick items up later if you have time or want to show them off.

Each item notes **what we did instead** and **how to add it later**.

---

## Phase 0: Foundation & Tooling

| Left out | What we did instead | How to add it later |
|---|---|---|
| Swift Package modules (Core, DesignSystem, Domain, Data, Features…) | One app target, code grouped by folder | Move a folder (e.g. `DesignSystem/`) into a local Swift package once the project gets big |
| `.xcconfig` secrets handling | `Config/Secrets.plist` (gitignored), read by `Secrets.swift` | Only worth it if you need different keys for Debug and Release builds |
| Dependency container (`AppEnvironment`) | `PetRepository` passed via `@Environment(\.petRepository)`; stores via `.environment(...)` | Group services into one struct when there are more than 3–4 |
| Logging with `os.Logger` | `print(...)` | Replace `print` with `Logger(subsystem:category:)` |
| Feature flags / remote config | None | Firebase Remote Config, or a simple `enum FeatureFlag` with `UserDefaults` toggles |
| SwiftLint / SwiftFormat | None | `brew install swiftlint`, add a `.swiftlint.yml` and a Run Script build phase |
| GitHub Actions CI (build + test on PR) | None | Add `.github/workflows/ci.yml` that runs `xcodebuild test` on `macos-15` |
| Branch strategy doc | Not written down | Follow SPEC §14: `feature/<phase>-<name>`, one PR per feature |
| Deep-link router (URL scheme, universal links) | `Router` handles tabs and navigation paths only, no URLs | Add a URL scheme in target Info, then `.onOpenURL` that maps URLs to `Route`s |
| One app-wide error type (`AppError`) with recovery actions | `APIError` with user-friendly messages | Add an error type with a `recovery` property if other error sources appear |
| Swift 6 strict concurrency | Swift 5 language mode | Set `SWIFT_VERSION = 6.0` and fix the warnings |
| String Catalogs / localization | Plain English strings | Add `Localizable.xcstrings`. Xcode extracts strings automatically (Phase 15) |
| Fuller design system: button variants (tertiary, destructive), haptics, `@ScaledMetric` icon sizes | `PFButton` has primary and secondary only; fixed icon sizes | Add variants and sizes to `Components.swift` when a screen needs them |
| Light/dark override in Settings (DESIGN.md) | The app follows the system setting | `@AppStorage("appearance")` plus `.preferredColorScheme(...)` on the root view |
| Tests (unit, UI, snapshot) | None, no test targets | File › New › Target › Unit Testing Bundle; start with `PetFilters.queryItems` and `PetfinderAnimal.toPet()` |
| ADRs (`docs/adr`) | None | Write short notes for big decisions (backend, ML approach) |

## Phase 1: Networking & Data Layer

| Left out | What we did instead | How to add it later |
|---|---|---|
| **API proxy (Cloud Function) so the secret never ships in the app** | Petfinder key and secret are in `Secrets.plist`, **bundled inside the app** | A Firebase Cloud Function that holds the secret and forwards `/animals` requests; point `PetfinderClient` at it |
| Generic `APIClient` with typed `Endpoint`s and interceptors | `PetfinderClient` built just for Petfinder | Only needed if you add a second API (e.g. RescueGroups) |
| Retry with exponential backoff | Retries once on 401 (expired token) only | Retry loop with `Task.sleep` on 429/5xx |
| ETag / HTTP caching for API responses | None (images are cached; API calls are not) | Use `URLCache` with the request's `cachePolicy`, or cache in Core Data |
| **Core Data offline cache** (cache-then-network, staleness policy) | No offline support; everything loads from the network | Core Data or SwiftData model for `Pet`; show cached pets first, then refresh |
| Generic pagination abstraction (cursor/page) | Simple `PetPage` with page numbers | Fine as is unless another API uses cursors |
| DTO fixtures (saved JSON samples) | `MockPetRepository` with generated pets | Save a real `/animals` response as `animals.json` for tests and previews |
| Unit tests for decoding, mapping, and error paths | None | See the Phase 0 tests row |
| RescueGroups as an alternative provider | Petfinder only | Second repository that implements `PetRepository` |

## Phase 2: Discovery Core

| Left out | What we did instead | How to add it later |
|---|---|---|
| Custom image pipeline (downsampling, own memory/disk cache) | `AsyncImage` + a bigger `URLCache`; cards use Petfinder's small "medium" photo | Custom `ImageLoader` actor with `NSCache` + `CGImageSourceCreateThumbnailAtIndex` |
| Image prefetching | Photos load when a card appears | `ImageLoader.prefetch(urls)` for the next few cards |
| Grid **and** list layout | Grid only | Toggle in the toolbar that switches between `LazyVGrid` and `List` |
| Shimmer animation on skeletons | Static `.redacted(reason: .placeholder)` cards | Add a moving gradient overlay; skip it when Reduce Motion is on |
| Filters: color, coat length, special needs, time in shelter | Species, breed, age, size, gender, good with kids/dogs/cats, house-trained, location + distance, sort | Add fields to `PetFilters` + `queryItems` (`color`, `coat`, `special_needs`, `before`/`after`) |
| Distance from **current GPS location** | Type a ZIP code or "City, ST" | Phase 5 `LocationService` → pass `"lat,long"` as `location` |
| "New today" rail | "Just added" = newest pets overall (not limited to today) | Add Petfinder's `after` parameter set to the start of today |
| Rails that respect your location/filters | Rails always show nationwide results | Pass the location from `filters` into the rail requests |
| Recently viewed stored in Core Data | Stored in `UserDefaults` (last 10); snapshots can go stale (e.g. pet already adopted) | Move to Core Data with the Phase 1 cache; refresh status on open |
| Filters persisted in Core Data | Saved in `UserDefaults` | Fine as is |
| Breed suggestions for every species | Uses the selected species, or dogs + cats if none is selected | Load all types from `/types` |
| Search across descriptions/tags | Name search only (Petfinder's `name` parameter) | Natural-language search is Phase 12 |
| Visible error when "load more" fails | Silently stops; scrolling to the end again retries | Show a "Couldn't load more · Retry" row at the bottom |
| Analytics events (`search_performed`, `filter_applied`, `pet_viewed`) | None | Firebase Analytics `logEvent` once Firebase is added |

## Phase 3: Pet Detail

| Left out | What we did instead | How to add it later |
|---|---|---|
| Video in the carousel | Photos only | Petfinder's `videos` field has embed HTML; show it in a `WKWebView` (Petfinder videos are YouTube embeds) |
| Universal link for sharing (`pawfinder.app/pet/123`) | `ShareLink` shares the Petfinder listing URL (or a text message for mock pets) | Needs a domain + Associated Domains (Phase 14) |
| Full description | Petfinder's API only returns a short preview; we show it with "Read more" plus a "View full listing on Petfinder" link | No API fix; this is a Petfinder limitation |
| Actions: apply, message shelter | Not on the detail screen yet (favorite was added in Phase 4) | Phase 9 (apply), Phase 10 (message) |
| Compatibility score with your lifestyle | Not shown | Phase 12 (needs the lifestyle questionnaire from Phase 7) |
| Distance from **your** location | Only shows distance when Discover had a typed location | Phase 5 `LocationService` |
| Shelter profile page (tapping the shelter) | Shelter card with name, address, mini-map, call/email/website; `Route.shelter` is still a placeholder | Phase 5 |
| Directions inside the app | Tapping the mini-map opens Apple Maps | Fine as is; Phase 5 can use `MKMapItem.openInMaps` for driving directions |
| Report listing sent to a backend/moderator | Saved on the device only (`UserDefaults` key `listingReports`) and a "thanks" message | Write to a Firestore `reports` collection once Firebase is added |
| Pan/zoom polish in the full-screen viewer (edge limits, momentum) | Pinch, double-tap to zoom, and drag while zoomed; no limits on how far you can drag | Clamp `offset` to the image bounds |
| Refreshing the pet's status when the detail opens | Shows the data from the grid/rail (could be stale from Recently viewed) | Call `repository.fetchPet(id:)` on appear and replace the pet |
| Shelter + geocoding cache | Shelter and its map location are fetched every time a detail opens | Keep a `[shelterID: Shelter]` dictionary in the repository |

## Phase 4: Favorites, Collections & Offline

| Left out | What we did instead | How to add it later |
|---|---|---|
| Core Data storage | One JSON file (`Documents/favorites.json`) written by `FavoritesStore` | Move to SwiftData/Core Data if the data gets large or needs queries |
| Outbox for offline changes (queue + retry to a server) | Not needed yet: favorites only live on the device, so every change is instant and works offline | Add when favorites sync to Firebase (Phase 8): queue writes while offline, send them when back online |
| Spotlight indexing of favorites | None | `CSSearchableIndex` with one `CSSearchableItem` per favorite; open the pet via `onContinueUserActivity(CSSearchableItemActionType)` |
| Notifications when a favorite's status changes | A dot and an "Adopted" / "No longer listed" label in Favorites, plus a banner on the detail screen | Phase 11 (push), or a local notification after a background refresh |
| Background status checks | Checked when the Favorites tab opens (at most once an hour) and on pull to refresh | `BGAppRefreshTask` to check while the app is closed |
| "Pending" status | Petfinder only reports adoptable/adopted/found, so we show "Adopted" or "No longer listed" | No fix; this is a Petfinder limitation |
| Offline photos | Photos come from the image cache, if they were loaded before | Save each favorite's first photo to disk when it's favorited |
| Reordering pets inside a collection from the detail screen | Reorder from the Favorites tab (Edit button); new pets go to the end | Fine as is |
| Unit/integration tests for the store | None | Test `FavoritesStore` with a temporary `fileName` |

## Later phases (5 onwards)

Not started yet. When a phase is built, anything left out or simplified gets added here under that phase's heading.

---

**Not yet verified:** Phases 0–4 were written without building in Xcode (the code was written on Windows). The first build on a Mac may surface small compile errors.
