# Leftover

Things from SPEC.md that are still left out or simplified, to keep PawFinder a manageable student project. Nothing here is required for the app to work. Pick items up later if you have time or want to show them off.

Each item notes **what we did instead** and **how to add it later**. Items that have been picked up since are listed at the bottom under **Done in the scope bump**.

**Ground rules for now:** no server to run, no paid plan, and no tests. Since the move to user-posted listings (see [Listers-and-Messaging.md](Listers-and-Messaging.md)), **Firebase Authentication and Firestore are in use** (free Spark plan). Items that need a server or a paid plan are marked *(server)*, *(paid)*, or *(tests)*; older *(cloud)* marks mean "needed Firebase", which is now partly available.

> ### Update: what the move to listers and real chat changed
> **No longer applies (done, or the thing it described is gone):**
> - Phase 1: the **Petfinder** client, OAuth token handling, retry/backoff, offline page cache, API proxy *(server)*, RescueGroups provider, and the saved-JSON fixtures. There is no external pet API any more. Firestore's own offline copy replaces the cache.
> - Phase 3: the "Petfinder only sends a short description" limitation, and "Report listing saved on the device only" (reports now go to Firestore `reports`).
> - Phase 9: the **simulated shelter** and "Cloud Function for status changes" (listers now review applications themselves; no function needed).
> - Phase 10: the **simulated shelter replies**, the local outbox, and "real-time chat with real shelters" (now real, via Firestore listeners).
>
> **Still open, or newly relevant:**
> - **Remote push** for chat/applications when the app is closed *(server, paid)*: needs Cloud Functions + APNs.
> - **Favorites/collections/followed listers don't sync across devices** (Phase 8 is still skipped).
> - **Application attachments aren't uploaded** (kept on the adopter's phone on purpose).
> - Distances are in **miles**; add a km/mi setting for non-US users.
> - Security rules are "good enough" for a class project, not hardened (see Listers-and-Messaging.md §14).
> - A moderator tool for `reports`, and verified-rescue badges, are ideas listed in Listers-and-Messaging.md §13.

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

## Phase 6: Core ML Breed Identification

**Skipped for now** (at your request). The Identify tab is now a **Breeds** hub (breed match quiz + breed browser; see Additions.md) with a "photo ID coming soon" card; photo identification can be added there later. Everything in SPEC §8 Phase 6 is still to do: dataset, Create ML training, `BreedClassifier`, photo/camera/live modes, mixed-breed results, history, and "Find adoptable [breed]".

## Phase 7: Auth & Accounts

| Left out | What we did instead | How to add it later |
|---|---|---|
| Google sign-in | Email or username + password, and Sign in with Apple | Add the `GoogleSignIn` package and enable Google in Firebase. App Store rules then require Sign in with Apple too (already there) |
| Sign in with Apple turned on | Code and button are in place; the capability is off because there's no paid Apple Developer account yet | docs/SETUP.md §4: one capability checkbox + enable Apple in Firebase |
| Our own Keychain token storage and silent refresh | Firebase Auth already keeps the session in the Keychain and refreshes tokens | Nothing to do |
| Guest data merging into the account across devices | On first sign-in on a phone, the guest's profile and photo move to the account. Favorites, collections, and followed shelters stay on the phone (not tied to an account) | Phase 8 (sync) |
| Avatar upload to the cloud (Firebase Storage) | Avatar saved on the device only (resized to 512px) | Phase 8: upload to Storage and save the URL in the user's Firestore document |
| Profile and lifestyle answers in the cloud | Saved on the device, one per account (`ProfileStore`) | Phase 8 |
| Server-side account deletion pipeline *(server)* | Deletes the Firebase account (with re-sign-in; Apple accounts also revoke the Apple token) and the profile on the device. There's no cloud data to delete yet | A `deleteUserData` Cloud Function once there's Firestore data |
| Data export request handled by a server *(server)* | "Export my data" makes a JSON file on the phone and shares it | Fine for now |
| Password reset for username accounts | Not possible (no real email). The sign-up screen says so | Ask for a recovery email, or require email accounts |
| Email verification | Not required | `user.sendEmailVerification()` after sign-up, and check `isEmailVerified` |
| Changing email or password in the app | Password reset by email only | `user.updatePassword(to:)` after re-authenticating |

## Phase 8: Cloud Sync

**Skipped** *(cloud)*. Favorites, collections, notes, saved profile, followed shelters, and applications all stay on the device. Everything in SPEC §8 Phase 8 is still to do: Firestore sync, conflict resolution, offline-to-online reconciliation, and multi-device testing.

## Phase 9: Adoption Application Workflow

| Left out | What we did instead | How to add it later |
|---|---|---|
| Cloud Function for status changes + a real shelter on the other end *(server, cloud)* | A **simulated shelter** in `ApplicationsStore`: on submit it plans replies (in review after 1 min, interview after 3, decision after 6) and applies them when their time comes. It declines renters without landlord permission or 10+ hours alone; otherwise approves | A shelter dashboard + Firestore + an `onApplicationStatusChange` Cloud Function |
| Push notifications for status changes *(server)* | Local notifications scheduled at submit time for each planned reply (cancelled if you withdraw) | Phase 11 |
| **Live Activity** for application status | Not built: Live Activities need a Widget Extension target | Phase 14, when the widget extension is added |
| Meet-and-greet scheduling with EventKit | A "best times to meet" text field in the form; the simulated shelter's interview note says they'll contact you | `EKEventEditViewController` to add the meeting to Calendar |
| Uploading attachments with progress *(cloud)* | Photos (ID, lease, vet reference, other) saved on the phone only, shown in the application | Firebase Storage upload with `StorageUploadTask` progress |
| Separate adopter profile screens (household, home type, pets, experience) | The application form asks these, pre-filled from the lifestyle questionnaire | Fine as is |
| Applications tied to the account | Stored on the device (`Documents/applications.json`), shared by whoever uses the phone | Phase 8 (sync) |
| Attaching PDFs / scanning documents | Photos only (from the photo library) | `fileImporter` for PDFs, `VNDocumentCameraViewController` for scanning |

## Phase 10: Messaging

| Left out | What we did instead | How to add it later |
|---|---|---|
| Real-time chat with real shelters (Firestore listeners) *(cloud)* | Chats are saved on the device; a **simulated shelter** reads your message after ~3s, shows "typing…", and replies ~7s after sending, with an answer based on keywords (visits, fees, kids, dogs, cats, health, applying…) | Firestore `conversations/{id}/messages` with snapshot listeners, plus a shelter-side app |
| Push notifications for replies *(server)* | Local notifications scheduled when you send (hidden if that chat is open) | Phase 11 + an `onMessageCreate` Cloud Function |
| Notification Service Extension (rich previews) | Not built: it needs an extension target | Add with the other extensions in Phase 14 |
| Outbox retrying against a server *(server)* | Messages written offline wait (shown as "Waiting to send") and go out when the phone reconnects (`NetworkMonitor` + `flushOutbox()`) | Same idea, sending to Firestore |
| Pagination from the server | All messages are on the device; the chat shows the last 40 with "Load earlier messages" | Query by date with `limit` once messages are in Firestore |
| Real moderation *(server)* | `ContentModerator` blocks a few abusive words and warns about payment/scam phrases before sending. Reports are saved on the device (`messageReports`) | Server-side checks and a review queue |
| Blocking across devices *(cloud)* | Blocking stops replies in that chat on this phone | Store blocks in Firestore |
| Real read receipts | Simulated: "Delivered" after 1s, "Read" after 3s | Comes with real chat |
| Sending messages with several photos or files | One photo per message (from the library) | `PhotosPicker` with `maxSelectionCount` |

## Phase 11: Notifications & Saved Search Alerts

| Left out | What we did instead | How to add it later |
|---|---|---|
| APNs registration and device token management *(server)* | No remote push. Everything is a **local** notification, from the background check or scheduled ahead of time | Needs a paid Apple Developer account (Push capability), `registerForRemoteNotifications`, and a server or FCM to send pushes |
| Server fan-out for saved searches, favorite status changes, and followed shelters *(server)* | The background check (`BackgroundRefresh`) looks for new matches, adoptions, and new arrivals on the phone and notifies | A scheduled Cloud Function (`matchSavedSearches`) |
| Alerts arriving at a predictable time | Background checks run when iOS decides (often every few hours, less if the app is rarely used) | Only real push fixes this |
| Saved-search alerts in sample-data mode | Sample pets never change, so saved searches don't find new matches without Petfinder keys | Use real keys to see alerts |
| Notification actions (e.g. "Reply" or "View pet" buttons on the notification) | Tapping opens the right screen | `UNNotificationCategory` with actions |
| Rich previews with pet photos | Text only | Notification Service Extension (Phase 14 with the other extensions) or attach the saved favorite photo with `UNNotificationAttachment` |
| Badge synced with a server *(server)* | The app icon badge is worked out on the phone: unread messages + favorites with a status change + new saved-search matches | Fine as is |

## Phase 12: Personalization & On-Device Intelligence

**Not started** (not part of the Phase 13–14 checkpoint). Compatibility scoring, the For You feed, natural-language search, and AI summaries are all still to do. The lifestyle questionnaire (Phase 7) is ready to feed compatibility scoring.

## Phase 13: Swipe, Compare & Care Hub

**Done:**

| SPEC item | What we built |
|---|---|
| Swipe card stack with gestures | `SwipeView` (Discover › stack icon): drag right = like (favorite), left = pass, up = super-like (favorite + "Top picks" collection). Uses Discover's current filters. Buttons do the same, for VoiceOver users |
| Haptics | Different feedback for like, pass, and super-like |
| Undo | Brings the last card back and reverses its effect |
| Prefetching | Loads the next page when fewer than 5 cards are left; the 2 cards under the top one are already rendered, so their photos load early |
| Compare view (2–3 pets, highlighted differences) | Favorites › Compare: pick 2–3, see 13 attributes side by side; differing rows are highlighted, with an "Only show differences" switch |
| Care Hub: articles, breed guides, persisted checklists | Profile › Care Hub: 6 guides (Markdown), 8 breed guides with "Find adoptable [breed]" (opens Discover filtered), 2 checklists whose ticks are saved |

**Not done:**

| Left out | What we did instead | How to add it later |
|---|---|---|
| Care Hub articles from remote config, with caching *(cloud)* | Articles are built into the app (`CareContent.swift`), so they work offline but need an app update to change | Firebase Remote Config or a JSON file on a server |
| Passed pets synced across devices *(cloud)* | Passed pets are remembered on this phone (last 1,000) | Phase 8 |
| Swiping powering recommendations | Swipes only favorite/pass for now | Phase 12: likes and passes as signals |
| Comparing from places other than Favorites | Compare starts from Favorites | Add a "Compare" action to pet detail |

## Phase 14: Platform Integrations

**Done:**

| SPEC item | What we built |
|---|---|
| App Intents + Shortcuts | `AppIntents.swift`: "Find adoptable pets" (optional animal type: "Show dogs in PawFinder"), "Open my favorite pets", "Show shelters near me", "Open my messages". They appear in the Shortcuts app and work with Siri without setup |
| Handoff | The pet detail screen advertises a `com.pawfinder.viewPet` activity; another device signed in to the same Apple ID can continue it (and a Mac can open the Petfinder page in Safari) |
| Spotlight | Already done in the scope bump (favorites are searchable) |
| Deep links | Already done; Siri intents also use them (`pawfinder://discover?species=dog`, `pawfinder://messages`) |

**Not done** (all need an **extension target**, a second app target that Xcode normally creates; adding one by hand to the project file without Xcode is too risky):

| Left out | Why | How to add it later |
|---|---|---|
| WidgetKit widgets (favorite pet, pet of the day, application status) | Needs a Widget Extension target and an App Group (App Groups need a paid account) to share data | File › New › Target › Widget Extension; move the favorites/applications JSON into the App Group container |
| Live Activity for application status | Lives in the same Widget Extension | Add an `ActivityConfiguration` in the widget extension; start it from `ApplicationsStore.submit` |
| Share extension ("Save to PawFinder") | Needs a Share Extension target + App Group | File › New › Target › Share Extension |
| Notification Service Extension (rich previews, from Phases 10–11) | Needs its own target | File › New › Target › Notification Service Extension |
| "Identify this pet" intent | Phase 6 (Core ML) was skipped | Add once breed identification exists |
| Universal links (`https://pawfinder.app/pet/123`) | Needs a domain you own + Associated Domains (paid account) | Host `apple-app-site-association`, add the entitlement |
| iPad split-view layout (`NavigationSplitView`) | Optional in SPEC; the tab layout already works on iPad | A `NavigationSplitView` for regular width |

## Sample data (works until the APIs are online)

The app always has something to show:
- **No Petfinder keys:** everything runs on the built-in sample data (`MockPetRepository`): 25 pets (with placeholder photos from placedog.net / cataas.com, falling back to a paw icon), 8 shelters with hours and addresses, breed lists, and Discover shows a "You're seeing sample pets" banner.
- **Keys present, but Petfinder down / offline with nothing cached / bad keys:** `FallbackPetRepository` quietly switches to the same sample data, with a "Petfinder isn't reachable" banner, instead of an error screen.
- **Simulated shelter:** applications (Phase 9) and messages (Phase 10) always use the simulated shelter, so they work without any backend.
- **Built in:** Care Hub content, breed guides, and checklists.

## Phase 17: Meet & Greet Planner (MapKit)

**Built:** place picker with search, shortcut chips and a centre pin; meet-up proposals as chat cards (accept, decline, suggest another, cancel); route, ETA and Look Around screen; reminders an hour before; upcoming meet-ups list; pet-photo map with clustering and a distance circle; nearby vets, pet stores, parks and groomers. Details in Listers-and-Messaging.md §15.

| Left out / simplified | Why | How to add it later |
|---|---|---|
| Draggable pin you hold and move | A fixed centre pin is simpler and works the same | Use `MapReader` with a long-press gesture |
| Transit route line on the map | MapKit only gives an estimate for transit | Open in Apple Maps |
| Showing both people's live position | Needs location sharing and a server | Out of scope |
| Reminder after the app is force-quit | Local notifications only; each phone schedules its own reminder while the app runs the chats listener | Needs push (Cloud Functions, paid plan) |
| A separate "Cancelled" notification | Chat messages already notify | Add to `MessagesStore.notifyIfNew` |
| Editing a proposal after sending | Use "Suggest another place or time" | Allow editing own proposals while `proposed` |
| Pins for pets with no coordinates | Needs a location on the listing | The count shows as "N without a location" |
| "Search this area" on the pet map | All active listings are already on the phone | Not needed |
| Photo of the meeting place in the card | Look Around is on the route screen | `MKMapSnapshotter` image |
| **Not compiled yet** | Written on Windows | Expect a small round of compile fixes (MapKit APIs: `LookAroundPreview`, `MapPolyline(route)`, `MKLookAroundSceneRequest`) |

## Later phases (15 onwards, and 18-20)

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

**Not yet verified:** Phases 0–5, 7, 9–11, 13–14 (partly), and the scope bump were written without building in Xcode (the code was written on Windows). The first build on a Mac may surface small compile errors.
