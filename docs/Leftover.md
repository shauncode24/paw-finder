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
> - Security rules are "good enough" for a class project, not hardened (see Listers-and-Messaging.md §14).
> - A moderator tool for `reports`, and verified-rescue badges, are ideas listed in Listers-and-Messaging.md §13.
>
> **Picked up in the leftover pass** (see the table at the bottom, "Done in the leftover pass"): km/mi setting, search across descriptions and tags, email verification, change password in the app, several photos per chat pick, lister replies to reviews, auto-declining other foster offers, Compare from a pet's page, and the ADR/branching docs.

---

## Phase 0: Foundation & Tooling

| Left out | What we did instead | How to add it later |
|---|---|---|
| Swift Package modules (Core, DesignSystem, Domain, Data, Features…) | One app target, code grouped by folder | Move a folder (e.g. `DesignSystem/`) into a local Swift package once the project gets big |
| `.xcconfig` secrets handling | Not needed any more: there are no API keys. The only config file is `GoogleService-Info.plist` (gitignored) | Only worth it if you need different Firebase projects for Debug and Release |
| Dependency container (`AppEnvironment`) | Each service goes in through `.environment(...)` | Group services into one struct if the list keeps growing |
| Feature flags / remote config | None | Firebase Remote Config, or a simple `enum FeatureFlag` with `UserDefaults` toggles |
| SwiftLint / SwiftFormat | None | `brew install swiftlint`, add a `.swiftlint.yml` and a Run Script build phase |
| GitHub Actions CI *(tests)* | None | Add `.github/workflows/ci.yml` that runs `xcodebuild build test` on `macos-15` |
| Branch strategy doc | **Done:** [BRANCHING.md](BRANCHING.md) | |
| Universal links (`https://pawfinder.app/pet/123`) | Custom-scheme deep links only (`pawfinder://pet/123`) | Needs a domain you own + Associated Domains (Phase 14) |
| One app-wide error type (`AppError`) with recovery actions | `APIError` and `LocationService.LocationError`, each with user-friendly messages | Merge them if more error sources appear |
| Swift 6 strict concurrency | Swift 5 language mode | Set `SWIFT_VERSION = 6.0` and fix the warnings |
| String Catalogs / localization | Plain English strings | Add `Localizable.xcstrings`; Xcode extracts strings automatically (Phase 15) |
| More button variants (tertiary, destructive) | `PFButton` has primary and secondary; destructive actions use `Button(role: .destructive)` | Add when a screen needs them |
| Tests (unit, UI, snapshot) *(tests)* | None, no test targets | File › New › Target › Unit Testing Bundle; start with `PetFilters.matches`, `ListingMapper` and `FosterProfile.problems` |
| ADRs (`docs/adr`) | **Done:** three short notes in [adr/](adr/) (Firebase free plan only, photos inside Firestore, filtering on the phone) | Add one for each big decision (the ML approach when Phase 6 happens) |

## Phase 1: Networking & Data Layer

Almost all of this was about the Petfinder API, which has been removed (see the note at the top). What is still true:

| Left out | What we did instead | How to add it later |
|---|---|---|
| Generic `APIClient` with typed endpoints | Not needed: the only backend is Firestore, behind `PetRepository` and the services | Only if a second, non-Firebase API appears |
| Full Core Data offline store | Firestore keeps its own offline copy of what it has loaded | SwiftData if you ever need queries on cached data |
| Unit tests with saved fixtures *(tests)* | None | Test `ListingMapper` with hand-written dictionaries |

## Phase 2: Discovery Core

| Left out | What we did instead | How to add it later |
|---|---|---|
| Image prefetching | Photos load when a card appears (thumbnails already arrive with the feed) | `PhotoLoader.prefetch(urls)` for the next few cards |
| Colour filter | Coat, special needs, and time listed exist; colour is free text on a listing, so it is searchable but not a filter | A list of common colours in the listing form |
| Recently viewed in Core Data | `UserDefaults` (last 10). Opening one refreshes its data | Fine as is |
| Breed suggestions for every species | `BreedCatalog` covers dogs, cats, rabbits and birds | Add more species lists |
| Search across descriptions/tags | **Done in the leftover pass**: the search box matches name, breed, temperament, colours, coat, place and the story, and every word must match | Natural-language search is Phase 12 |
| Analytics events | `os.Logger` logs only | Firebase Analytics `logEvent` once Firebase is added |

## Phase 3: Pet Detail

| Left out | What we did instead | How to add it later |
|---|---|---|
| Universal link for sharing *(needs a domain)* | `ShareLink` shares a text message with the pet's details | Phase 14 |
| Compatibility score with your lifestyle | Not shown | Phase 12 (needs the lifestyle questionnaire from Phase 7) |
| A screen for moderators to read `reports` | Reports are saved in Firestore `reports`; nobody reads them in the app | Admin role (not selected) |
| Momentum when dragging a zoomed photo | Drag stops when your finger lifts | Animate the offset with the drag's predicted end |

## Phase 4: Favorites, Collections & Offline

| Left out | What we did instead | How to add it later |
|---|---|---|
| Core Data storage | One JSON file (`Documents/favorites.json`) plus saved photos in `Documents/FavoritePhotos/` | SwiftData/Core Data if the data gets large or needs queries |
| Outbox for offline changes *(server)* | Not needed yet: favorites only live on the device | Add with cloud sync (Phase 8) |
| Push notifications *(server)* | **Local** notifications from the background check | Phase 11 |
| Reordering inside a collection from the detail screen | Reorder from the Favorites tab (Edit button) | Fine as is |
| Tests for the store *(tests)* | None | Test `FavoritesStore` with a temporary `fileName` |

## Phase 5: Location, Map & Shelters

| Left out | What we did instead | How to add it later |
|---|---|---|
| Continuous location updates (`AsyncStream`) | `LocationService` gets the location once when asked; the map's blue dot (`UserAnnotation`) tracks you by itself | Wrap `CLLocationUpdate.liveUpdates()` if a feature needs live tracking |
| MapKit's built-in clustering | A simple grid clustering (`ShelterCluster.make`) that regroups when the map stops moving | `MKMapView` in a `UIViewRepresentable` with `clusteringIdentifier` |
| Exact lister coordinates | Listers save a city/postcode, which is looked up with Apple's geocoder when they save their profile (city-level on purpose) | Fine as is |
| Filter listers by which animals they have | Chips for distance, "Open now", and "Following" | Count species from the live feed |
| Lister photo gallery | One avatar as the header | Reuse `PhotoCarousel` with a few photos |
| Accurate "open now" | Best-effort reading of the free-text hours ("9-5", "10am-6pm", "Closed"), using the phone's time zone | Unreadable hours show nothing rather than a wrong answer |
| Push notifications for new arrivals *(server)* | Local notifications from the background check (iOS decides when it runs) | Phase 11 |
| Geofencing (optional in SPEC) | None | `CLMonitor` with a region around followed shelters |
| Offline lister search | Lister profiles and coordinates are cached; Firestore's offline copy covers the rest | Fine as is |

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
| Server-side account deletion pipeline *(server)* | The app deletes the account (with re-sign-in), the person's listings and photos, lister profile and foster profile, and the profile on the device. Chats, applications, reviews and journeys stay so the other person's history isn't broken | A `deleteUserData` Cloud Function |
| Data export request handled by a server *(server)* | "Export my data" makes a JSON file on the phone and shares it | Fine for now |
| Password reset for username accounts | Not possible (no real email). The sign-up screen says so; **Change password** (below) works for them while signed in | Ask for a recovery email, or require email accounts |
| Email verification | **Done in the leftover pass:** a link is sent when an email account is created; Account shows "Your email isn't verified yet" with Send again / "I've verified". It is **not required** to use the app | Gate listing or chatting on `isEmailVerified` |
| Changing the password in the app | **Done in the leftover pass:** Account › Change password (asks for the current one first) | |
| Changing the email address in the app | Not built | `user.sendEmailVerification(beforeUpdatingEmail:)` |

## Phase 8: Cloud Sync

**Skipped** *(cloud)*. Favorites, collections, notes, saved profile, followed shelters, and applications all stay on the device. Everything in SPEC §8 Phase 8 is still to do: Firestore sync, conflict resolution, offline-to-online reconciliation, and multi-device testing.

## Phase 9: Adoption Application Workflow

The simulated shelter and its Cloud Function are gone: listers review applications themselves (see the note at the top). Still true:

| Left out | What we did instead | How to add it later |
|---|---|---|
| **Live Activity** for application status | Not built: Live Activities need a Widget Extension target | Phase 14, when the widget extension is added |
| Meet-and-greet scheduling with EventKit | Superseded by the Meet & Greet planner (Phase 17), which has its own reminder | `EKEventEditViewController` to also add it to Calendar |
| Uploading attachments | Photos (ID, lease, vet reference, other) stay on the adopter's phone on purpose | Only if you accept storing sensitive photos online |
| Applications tied to the account across devices | Drafts live on the phone (`Documents/applications.json`); submitted ones are in Firestore | Re-create drafts from Firestore on a new phone |
| Attaching PDFs / scanning documents | Photos only | `fileImporter` for PDFs, `VNDocumentCameraViewController` for scanning |

## Phase 10: Messaging

Chat is real now (Firestore listeners, typing, receipts, photos, report/block, offline outbox). What is left:

| Left out | What we did instead | How to add it later |
|---|---|---|
| Push notifications for replies *(server)* | Local notifications while the app is open or on iOS's background refresh | Cloud Functions + APNs |
| Notification Service Extension (rich previews) | Not built: it needs an extension target | Add with the other extensions in Phase 14 |
| Real moderation *(server)* | `ContentModerator` blocks a few abusive words and warns about payment/scam phrases before sending; reports go to Firestore `reports` | A moderator screen or server-side checks |
| Sending messages with several photos | **Done in the leftover pass:** pick up to 4 photos at once; each is sent as its own message | |
| Files other than photos | Not built | `fileImporter` + inline base64 would hit Firestore's 1 MB document limit quickly |

## Phase 11: Notifications & Saved Search Alerts

| Left out | What we did instead | How to add it later |
|---|---|---|
| APNs registration and device token management *(server)* | No remote push. Everything is a **local** notification, from the background check or scheduled ahead of time | Needs a paid Apple Developer account (Push capability), `registerForRemoteNotifications`, and a server or FCM to send pushes |
| Server fan-out for saved searches, favorite status changes, and followed shelters *(server)* | The background check (`BackgroundRefresh`) looks for new matches, adoptions, and new arrivals on the phone and notifies | A scheduled Cloud Function (`matchSavedSearches`) |
| Alerts arriving at a predictable time | Background checks run when iOS decides (often every few hours, less if the app is rarely used) | Only real push fixes this |
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
| Comparing from places other than Favorites | **Done in the leftover pass:** a pet's ••• menu has "Compare with similar pets" | |

## Phase 14: Platform Integrations

**Done:**

| SPEC item | What we built |
|---|---|
| App Intents + Shortcuts | `AppIntents.swift`: "Find adoptable pets" (optional animal type: "Show dogs in PawFinder"), "Open my favorite pets", "Show shelters near me", "Open my messages". They appear in the Shortcuts app and work with Siri without setup |
| Handoff | The pet detail screen advertises a `com.pawfinder.viewPet` activity; another device signed in to the same Apple ID can continue it |
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

## Sample data

There is no built-in sample data any more: Discover shows what people have listed (or "No pets listed yet"). `MockPetRepository` is used only by SwiftUI previews. Built in: Care Hub content, breed guides, and checklists.

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

## Phase 18: Lister Reviews

**Built:** star rating plus note after an adoption, edit for 7 days, average on pet pages and lister profiles, reviews screen, report a review, Welcome home and application-detail prompts, rules that protect the totals. Details in Listers-and-Messaging.md §16.

| Left out / simplified | Why | How to add it later |
|---|---|---|
| Lister replies to reviews | **Done in the leftover pass:** one public reply per review, which the lister can edit or remove | |
| Lister confirms the adoption before a review counts | Today the adopter marks it adopted themselves, so fake adoptions are possible | Add a "Confirmed by lister" status (Phase 19 fits) |
| Totals reduced when a review's author deletes their account | Needs a server (Cloud Functions) | Out of scope |
| Review photos, helpful votes, sorting | Not needed | |
| Reviews on a pet instead of a lister | Spec asked for listers | |
| A moderator screen to remove reviews | Reports are saved but nobody reads them in the app | Admin role (not selected) |
| **Not compiled yet, rules untested** | Written on Windows; Firestore rules can't be run here | Use Firebase console > Rules > Rules Playground if a review is rejected |

## Phase 19: Adoption Journey

**Built:** journey page with Day 1 / Week 1 / Month 1 / Month 3 check-ins and checklists linked to Care Hub guides; photo-and-note updates; lister view of the updates; "Happy tails" featured on a lister profile with the adopter's on/off switch; check-in reminders; progress on Profile and My applications. Details in Listers-and-Messaging.md §17.

| Left out / simplified | Why | How to add it later |
|---|---|---|
| Lister confirms the adoption | The spec didn't include it; today either side can mark Adopted | Add a "confirmed" step before a review or journey counts |
| Telling the lister about a new update | Needs push (a server) | Local notification from a listener while the app is open |
| Vet records, weight tracker, videos | Out of scope | |
| Return / re-homing flow | Out of scope | |
| Editing an update | Delete and repost | Allow `text` edits in the rules |
| Syncing ticked tasks between devices | They live in UserDefaults | Store ticks on the journey document |
| Reminders for someone who never reopens the app | Scheduled when the journey is created/opened | Needs push |
| Cleaning up journeys when an account is deleted | Needs a server | Out of scope |
| Happy tails for guests | Rules say signed-in only | Change the read rule to `if true` |
| **Not compiled yet, rules untested** | Written on Windows | Expect small compile fixes |

## Phase 20: Foster Volunteers

**Built:** foster volunteer profile (city-level location, what you can take, how long); "Needs a foster" on listings with a badge, filter and banner; offers to foster that the lister accepts or declines; "In foster care with <name>" on the listing; a directory of volunteers (list and map) for listers with "Invite to foster"; notifications; rules. Details in Listers-and-Messaging.md §18.

| Left out / simplified | Why | How to add it later |
|---|---|---|
| Background checks, foster agreements, documents | Not possible without a real vetting process | Out of scope |
| Supplies, donations, stipends, vet-cost tracking | Out of scope | |
| Clustering on the foster map | Few volunteers per area | Reuse `PetCluster` with a generic item type |
| Auto-declining other offers after one is accepted | **Done in the leftover pass:** accepting an offer declines the other waiting ones for that pet in the same step | |
| A foster's own "My foster pets" screen | The pet's page and the offer show it | Query listings by `fosterByID` (needs an index) |
| Ending a placement from the foster's side | The lister controls the listing | Rule branch for the foster |
| Visible-to-listers check is "has a lister profile" | Anyone can become a lister | Admin-approved listers (Admin role was not selected) |
| Reminder when a foster period ends | Needs dates on offers | Add start/end dates and a local reminder |
| **Not compiled yet, rules untested** | Written on Windows | Expect small compile fixes |

## Later phases (15 onwards)

Not started yet. When a phase is built, anything left out or simplified gets added here under that phase's heading.

---

## Done in the leftover pass

Picked up from the tables above because they needed no server, no paid plan and no extension target:

| Item | Where |
|---|---|
| Kilometres or miles (Settings › Units); chips, cards, lists and maps follow it. Searching still works in miles internally | `Models/DistanceUnit.swift`, `SettingsView`, and every place that shows a distance |
| Search matches descriptions, temperament, colours, coat, place and age/size, and needs every typed word to match | `PetFilters.matches` in `Models/Listing.swift` |
| Email verification (link sent on sign-up, status and re-send in Account; not required to use the app) | `AuthManager`, `AccountView` |
| Change password in the app | `AuthManager.changePassword`, `ChangePasswordSheet` |
| Up to four photos per pick in chat | `ChatView.sendPhotos` |
| Lister replies to reviews (+ rule) | `Review.reply`, `ReviewsService.reply`, `ReviewReplySheet`, `firestore.rules` |
| Accepting a foster offer declines the others | `FosterStore.respond` |
| "Compare with similar pets" from a pet's page | `PetDetailView` |
| Branching notes and architecture decision records | `docs/BRANCHING.md`, `docs/adr/` |
| Leftover.md cleaned up: Petfinder-era rows removed or rewritten | this file |

**Considered and left out on purpose:** syncing favorites across devices (Phase 8: a big change to `FavoritesStore` that is too risky to write without compiling), "lister confirms the adoption" (changes the application flow), notification actions and rich previews (need delegate work or an extension), anything needing push, Cloud Functions, a paid Apple account or a new Xcode target.

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
