# PawFinder: project facts

Raw material for a report. This is a flat collection of facts about the project, grouped by topic, in no particular report order. Nothing here is written as report prose, and the grouping is not a suggested structure. Items marked **(unverified)** could not be checked from the development machine.

---

## Identity

- **Name:** PawFinder
- **Type:** native iOS app, pet adoption marketplace
- **Language / UI framework:** Swift 5 language mode, SwiftUI
- **Minimum iOS:** 17.0. **Devices:** iPhone and iPad (`TARGETED_DEVICE_FAMILY = 1,2`)
- **Bundle identifier (placeholder):** `com.example.pawfinder`. **Version:** 1.0
- **Project shape:** one Xcode project, one app target, folder-synchronised groups, one Swift package dependency (`firebase-ios-sdk`, products FirebaseAuth and FirebaseFirestore)
- **Backend:** Firebase Authentication and Cloud Firestore on the free Spark plan. No custom server, no Cloud Functions, no Cloud Storage
- **Author context:** university project (Somaiya, Year 4, SwiftUI course); a student project, explicitly **not production-grade**
- **Repository:** Git, branch `main`, 21 commits between 2026-10-21 and 2026-10-22 (history below)
- **Development setup:** code written on Windows with Claude Code (an AI coding assistant) in VS Code; compiled and run on a Mac by the student, who pasted compile errors back for fixing

## Problem and idea

- Pet adoption listings usually sit on shelter websites with a poor experience; the original spec's goal was "the best native iOS experience for finding and adopting a pet, from first browse to application approved"
- First version used the **Petfinder API** as the source of pets, with simulated shelter replies
- The design was changed so that **users post the listings themselves** (individuals and rescues), removing the external API completely, and chat and applications became real person-to-person features
- Result: a small two-sided marketplace plus follow-up features after adoption (journey, reviews) and a third persona (foster volunteers)

## Personas (one account, no separate logins)

| Persona | How someone becomes it | Main actions |
|---|---|---|
| Adopter | Anyone; guests can browse and favourite, account needed to message/apply/list/review/foster | Browse, search, favourite, compare, chat, plan meet-ups, apply, adopt, follow the journey, review the lister |
| Lister | Saves a lister profile (individual or organisation) | Post and manage listings, receive and process applications, chat, propose meet-ups, mark pets adopted, reply to reviews, feature Happy tails, find foster volunteers |
| Foster volunteer | Saves a foster profile | Offer to foster pets marked "needs a foster", receive accept/decline |

## Feature inventory (what exists in the code)

### Discovery
- Discover tab: grid/list toggle (remembered), horizontal rails ("New today"/"Just added"), shimmer loading placeholders (disabled by Reduce Motion), offline banner, empty states ("No pets listed yet", "Not connected yet"), "Couldn't load more" retry
- Search matches name, breed, species, place, age, size, temperament, colours, coat and the story text; every typed word must match
- Filters: species, breed (suggestions), age, size, gender, good with kids/dogs/cats, house-trained, special needs, coat, time listed (today/this week/waiting 3+ months/1+ year), needs a foster, location + distance, sort (newest, longest waiting, nearest, random)
- Location: current location, or typed postcode/city; distance shown in miles or kilometres (Settings)
- Saved searches with alerts; filters remembered between launches
- Recently viewed (last 10)
- Swipe mode: right = favourite, left = pass, up = super-like (adds to a "Top picks" collection), undo, haptics, button alternatives for VoiceOver
- Breeds tab: lifestyle-based breed-match quiz and breed browser
- Care Hub: 6 guides (Markdown), 8 breed guides with "Find adoptable [breed]", 2 persistent checklists, "Vets and pet shops near you"

### Pet page
- Photo carousel with zoom and pan clamping; facts, health flags (vaccinated, spayed/neutered, microchipped), fee, special needs notes, video link
- Lister card with rating, contact buttons, distance, link to profile
- Similar pets rail; share; report listing; Handoff; "Compare with similar pets"
- Owner view with edit and "Applications received"; banners for pending/adopted/removed/needs foster/in foster care

### Favourites
- Favourites with notes, collections, reorder, status-change badges, offline copies of photos, Spotlight indexing, side-by-side Compare (2-3 pets, differences highlighted)
- Followed listers with new-arrival alerts

### Listing tools (lister)
- Lister profile (person or organisation, bio, city/state/postcode, contact, website, adoption policy, avatar)
- Listing form: up to 5 photos, breed with suggestions (dogs, cats, rabbits, birds), mixed breed, age and exact age, gender, size, colours, coat, weight, temperament chips, compatibility (kids/dogs/cats), house-trained, health flags, notes, fee, story, video link, location, optional contact, status, "needs a foster"
- My listings: edit, change status (available / pending / adopted), delete, interest counts
- Applications received: status buttons (start review, interview, approve, decline, mark adopted) with optional notes

### Chat
- Live messages, day separators, "Sending / Sent / Read" receipts, typing indicator (8-second window), up to 4 photos per pick (each sent as its own message), copy, report message, report/block conversation, offline banner and outbox ("Waiting to send"), unread counts, 40-message paging
- Content moderation: blocks a few abusive words, warns on payment/scam phrases
- Conversations are per pet per adopter; ID `<listingID>_<adopterID>`

### Meet & Greet planner (Phase 17)
- Place picker: search-as-you-type suggestions, shortcut chips (dog parks, cafés, vets, pet stores), centre pin with reverse-geocoded address, date and time
- Meet-up proposals are chat messages: accept, decline, suggest another place/time, cancel; statuses proposed/accepted/declined/changed
- Route screen: driving/walking/transit, travel time and distance, "leave by" time, Look Around street-view preview, open in Apple Maps
- Local reminder one hour before; "Upcoming meet-ups" section in Messages
- Pets map: photo pins, grid clustering, stacked-pet list for identical coordinates, distance circle, species chips, pet card; separate Listers map (lister pins, open now, following, list view)
- Nearby places: vets, pet stores, dog parks, groomers with call and directions

### Applications
- Six-step form (about you, home, pets and experience, plans, documents, review) pre-filled from the lifestyle profile, autosaved drafts, validation, optional document photos kept on the phone
- Submit to Firestore; lister updates status; adopter follows a timeline live; checklist after approval; withdraw; "we brought them home"
- Rules enforced in the app: cannot apply to own listing

### After adoption
- **Adoption journey** (Phase 19): check-ins Day 1 / Week 1 / Month 1 / Month 3 with short task lists and links to Care Hub guides; reminders for Week 1, Month 1, Month 3; photo-and-note updates (500 characters, one compressed photo); lister can read updates; "Happy tails" feature on lister profile with adopter's on/off switch; progress shown on Profile and My applications
- **Reviews** (Phase 18): 1-5 stars + note (500 characters), one per adoption, editable 7 days, average on pet page and lister profile, reviews list, report review, lister public reply
- Celebration screen with confetti, share, rate the lister, find a vet

### Fostering (Phase 20)
- Foster profile (animals, sizes, capacity 1-10, duration, home, other pets, experience, bio, city-level location, availability switch)
- "Needs a foster" flag with reason and duration; badge on cards; filter; banner
- Offers (one per volunteer per pet); lister accepts/declines; accepting declines other waiting offers; listing shows "In foster care with <first name + initial>"; lister can end placement
- Directory for listers (list and map, distance and species chips, "Invite to foster" opens a chat)

### Accounts and settings
- Email or username + password, Sign in with Apple (code present; capability off because no paid Apple Developer account), password reset by email, email verification (not enforced), change password, export my data (JSON), delete account (removes listings, photos, lister profile, foster profile)
- Usernames are stored as hidden emails `<name>@users.pawfinder.app`
- Settings: theme (system/light/dark), distance units (miles/kilometres), notification categories and quiet hours, permissions links, erase local data
- Onboarding (welcome, account, lifestyle, location), lifestyle questionnaire, Help & FAQ, privacy policy, terms, About

### System integration
- Siri/Shortcuts via App Intents (find adoptable pets, open favourites, shelters near me, open messages)
- Spotlight indexing of favourites; Handoff of the pet page
- Deep links with scheme `pawfinder://`: pet, shelter, application, conversation, received application, journey, foster, search, discover (with filters), messages, settings, tab names
- Background refresh task that checks favourites, new arrivals, saved searches, chats, applications and foster offers
- Badge on the app icon and the Profile tab

### Notifications (all local)
Categories: favourite pet updates, new pets at followed listers, saved search matches, application updates, messages, adoption journey check-ins, foster offers. Per-category switches, quiet hours, a "priming" explanation screen before the system prompt. No remote push.

### Accessibility and polish
Dynamic Type via `@ScaledMetric` icon sizes, VoiceOver labels and alternatives to gestures, Reduce Motion respected, light/dark colours defined as tokens, haptics on key actions, launch screen matching the background.

## Technology

- **Apple frameworks:** SwiftUI, Observation, MapKit (Map, Marker, Annotation, MapPolyline, MapCircle, MKLocalSearch, MKLocalSearchCompleter, MKDirections, LookAroundPreview, MKMapItem), CoreLocation, UserNotifications, BackgroundTasks, PhotosUI, AppIntents, CoreSpotlight, AuthenticationServices, CryptoKit, StoreKit (review prompt), Network (reachability)
- **Third party:** Firebase iOS SDK (Auth, Firestore). No other packages
- **Concurrency:** async/await, `@MainActor` stores, Firestore snapshot listeners for real time
- **Persistence on the phone:** UserDefaults and JSON files in Documents/Caches (favourites, applications drafts, saved searches, followed listers, notification preferences, journey ticks, geocoder cache)
- **Design system:** colour tokens (light + dark in asset catalog), spacing/radius constants, `PFButton`, `PFCard`, `PFChip`, loading/empty/error views, `FlowLayout`

## Architecture

- Folders: `App/` (entry, router, tab bar), `Screens/` (one folder per area, views and view models), `DesignSystem/`, `Models/`, `Services/`
- Navigation: one `NavigationStack` per tab (Discover, Map, Breeds, Favorites, Profile); a typed `Route` enum and a `Router` handle pushes, tab switches, deep links and notification taps
- State: `@Observable` stores injected through `.environment(...)`
- Data access: `PetRepository` protocol implemented by a Firestore-backed repository; a mock repository exists for previews only
- Live feed: one Firestore listener on active listings (newest 500); search, filter, sort and distance all run on the phone, so no Firestore composite indexes are needed
- Photos stored inside Firestore documents as base64 JPEGs: 280 px thumbnail in the listing, up to five 900 px photos in a subcollection, 800 px chat/journey photos, 160 px avatars; private `pfphoto:` URL scheme resolved by `PhotoLoader`
- Real time without a server: snapshot listeners act as the socket; Firestore's offline queue acts as the outbox
- Swift type-checker performance was a recurring concern (long expressions split into helpers)

## Firestore data model

| Collection | Content | Readable by |
|---|---|---|
| `users/{uid}` | Lister profile, rating totals (`ratingSum`, `ratingCount`) | Everyone |
| `listings/{id}` and `photos/{n}` | Pets and their photos | Everyone |
| `conversations/{id}` and `messages/{id}` | Chats, photos, meet-up proposals | The two participants |
| `applications/{id}` | Applications (form and events stored as JSON text) | Adopter and lister |
| `reviews/{applicationId}` | Reviews and lister replies | Everyone |
| `journeys/{applicationId}` and `updates/{id}` | Journey and photo updates | Adopter and lister |
| `happyTails/{updateId}` | Featured updates | Signed-in users |
| `fosters/{uid}` | Foster profiles (city only) | The volunteer and listers |
| `fosterOffers/{listingId_fosterId}` | Offers to foster | The two people |
| `reports/{id}` | Reports of listings, chats, reviews | Write-only from the app |

## Security rules (`firestore.rules`, about 260 lines)

- Owner-only writes to profiles and listings; listing photos checked against the listing owner (using `getAfter` for same-batch writes)
- Chats and messages limited to the two participants; no sending while blocked; meet-up messages may only change `meetup.status`
- Applications: adopter creates with status "Submitted"; lister updates; adopter can only withdraw or mark adopted
- Reviews: only the adopter of an *Adopted* application, 1-5 stars, editable for 7 days, never deletable; lister may only add/change/remove a `reply`
- Rating totals on `users/{uid}` can only change together with a matching review in the same batch (the owner cannot set them)
- Journeys created only by the adopter of an *Adopted* application; Happy tails only while the adopter's sharing switch is on
- Foster profiles restricted to an allow-list of fields, so a street address cannot be stored; readable only by the owner and listers
- Foster offers: created only by the volunteer for a pet that currently needs a foster, one per volunteer per pet; lister accepts/declines or volunteer withdraws, once, while pending
- Rules were written without the ability to run the Firebase rules tester **(unverified)**

## Development timeline (from git)

| Date | Commit |
|---|---|
| 2026-10-21 | phase 1, phase 2, phase 3, phase 4, added more functionalities, phase 5, phase 7, phase 9, phase 10, phase 11, parts of phase 13 and 14, further refinements, shelterview bug fix 1 |
| 2026-10-22 | replace api with manual listings, phase 17, phase 18, phase 19, phase 20, polished functionalities, submit not working fixed |

Phase 0 (project setup) was done before the first commit. Phase numbering follows `docs/SPEC.md`.

## Phases

| Phase | Status |
|---|---|
| 0 Foundation | Done (simplified) |
| 1 Networking and data | Done for Petfinder; later replaced by the Firestore listings layer |
| 2 Discovery | Done |
| 3 Pet detail | Done |
| 4 Favourites, collections, offline | Done |
| 5 Location, map, shelters | Done |
| 6 Core ML breed identification | **Skipped / deferred** (Breeds tab has a "coming soon" card) |
| 7 Accounts | Done (Apple capability off) |
| 8 Cloud sync of favourites etc. | **Skipped** |
| 9 Applications | Done (real, after the pivot) |
| 10 Messaging | Done (real, after the pivot) |
| 11 Notifications and alerts | Done (local only) |
| 12 Personalisation / on-device intelligence | **Skipped** |
| 13 Swipe, compare, Care Hub | Done |
| 14 Platform integrations | Partly (App Intents, Handoff, Spotlight; no extensions) |
| 15 Quality, accessibility, performance | Not done as a phase (some accessibility done along the way) |
| 16 Release engineering | Not done |
| 17 Meet & Greet planner (MapKit) | Done |
| 18 Lister reviews | Done |
| 19 Adoption journey | Done |
| 20 Foster volunteers | Done |
| Extras | "Additions" pass (onboarding, Breeds hub, settings, FAQ, polish) and a "leftover" pass (km/mi, richer search, email verification, change password, multi-photo chat, review replies, auto-decline foster offers, compare from pet page) |

## Key decisions and the reasons given

- **Scope reduced early:** the first Phase 0 setup was rebuilt "minimal" after the student said it was too advanced and not meant to be production-grade
- **No tests, no server, no paid plan:** stated constraints; therefore no unit/UI tests, no CI, no Cloud Functions, no push notifications, no Cloud Storage
- **Petfinder removed:** to allow user-posted listings and real chat; removed the API client, keys, offline page cache and sample data
- **Firestore-only on the free plan:** Storage and Cloud Functions need the paid Blaze plan, so photos are inline and notifications are local (ADR 0001, 0002)
- **Filtering on the phone:** avoids Firestore indexes and keeps reads low (ADR 0003)
- **Application attachments (ID, lease) stay on the phone:** deliberate privacy choice
- **Foster profiles in their own collection:** because `users/{uid}` is public and foster data must be visible to listers only
- **Core ML postponed** by the student; Phase 8 and 12 skipped by the student's choice
- **Extension targets avoided** (widgets, share extension, notification service extension, Live Activities): adding targets by hand to the project file without Xcode was judged too risky

## Problems met during development

- Type-checker timeouts in `ShelterMapView` and in application summary helpers (fixed by splitting expressions and adding explicit types)
- MapKit API misuse reported from the Mac build (`annotationTitles`, `onEnd` inference) fixed
- Over-engineered first setup (rebuilt smaller)
- Offline-hanging awaits solved with a 15-second timeout helper and by not awaiting queued writes (chat)
- Firestore rules pitfalls handled by design: `getAfter` for same-batch writes, allowing `resource == null` so "does it exist" checks work
- Cloud Storage requiring the paid plan, which forced the photos-in-Firestore design
- "Cannot submit the adoption form" bug report: likely causes were validation errors hidden at the bottom of a long form, a silent redirect to sign-in, and misleading failure messages; fixed by moving errors above the buttons, auto-continuing after sign-in, clearer messages and a keyboard Done button. The exact original cause was not confirmed

## Size

- 114 Swift source files, about 19,000 lines
  - App: 5 files, ~480 lines
  - Screens: 59 files, ~12,200 lines
  - DesignSystem: 5 files, ~300 lines
  - Models: 18 files, ~2,300 lines
  - Services: 27 files, ~3,800 lines
- Documentation: about 1,800 lines of Markdown across 12 files; `firestore.rules` about 260 lines
- Screen folders: Account, Applications, Breeds, CareHub, Discover, Favorites, Foster, Journey, Lister, Map, Messages, Notifications, Onboarding, PetDetail, Reviews, Settings, Shelters, Swipe

## Free-plan limits relevant to the design (figures from third-party guides; verify at firebase.google.com/pricing) **(unverified)**

- Firestore: about 50,000 reads/day, 20,000 writes/day, 1 GiB stored
- A listing with photos is roughly 0.5-1 MB, so about 1,000 listings fit; the feed shows the newest 500 active ones
- A chat message costs about two writes
- Document size limit 1 MB (hence small compressed photos, max 5 per listing)

## Known limitations

- **The code was written on Windows and has never been fully compiled or run as a whole.** Phases 17-20 and the leftover pass are uncompiled and untested; earlier phases were built by the student on a Mac in the early stages and fixed after reported errors
- No automated tests of any kind
- No push notifications to a closed app; alerts depend on the app being open or iOS's background refresh
- Security rules are "good enough" for a class project, not hardened: anyone can become a lister (so can see the foster directory), no vetting or background checks, no moderator screen for reports, an adopter can mark an adoption complete (fake adoptions/reviews possible), reviews are not removed when a reviewer deletes their account
- Account deletion does not remove chats, applications, reviews or journeys (so the other person's history is kept)
- Favourites, collections, notes and followed listers do not sync across devices
- Sign in with Apple switched off (no paid Apple Developer account)
- No localisation (English only), no Swift 6 strict concurrency, no iPad-specific layout
- Photos are small and limited to five per listing
- Pet map shows only listings that have coordinates
- Distances are stored in miles internally

## Not built (ideas recorded in `docs/Leftover.md`)

Core ML breed identification (photo, camera, live mode, mixed breeds, history); cross-device sync; personalisation and natural-language search; widgets, Live Activities, share extension, notification service extension; universal links; remote push; Admin/moderator role and verified-lister badges; lister confirmation of adoption; background checks and agreements for fosters; vet records and weight tracker in the journey; PDF attachments; notification actions and rich previews; localisation; CI and tests.

## Setup needed to run it

1. Mac with Xcode 16+; set signing team and a unique bundle identifier
2. Firebase project with an iOS app; `GoogleService-Info.plist` placed in `PawFinder/` (gitignored)
3. Enable Email/Password sign-in
4. Create a Firestore database (production mode) and publish `firestore.rules`
5. Optional: Sign in with Apple capability (paid account)
Without Firebase the app runs as a guest and shows "Not connected yet".

## Documents in the repository

`README.md`; `docs/SPEC.md` (original plan, 16 phases + added 17-20); `docs/SETUP.md`; `docs/PROJECT-OVERVIEW.md` (end-to-end description); `docs/Listers-and-Messaging.md` (data model, rules, chat, applications, meet-ups, reviews, journeys, fostering); `docs/Leftover.md` (what was left out and why); `docs/Additions.md` (extra polish); `docs/ARCHITECTURE.md`; `docs/CONVENTIONS.md`; `docs/DESIGN.md`; `docs/CLAUDE.md` (notes for the AI assistant); `docs/BRANCHING.md`; `docs/adr/0001-0003` (decision records); `firestore.rules`.

## How the user tests it (documented two-account plan)

Account A lists a pet; account B sees it in Discover, messages A, proposes and accepts a meet-up, applies; A moves the application to approved and adopted; B opens the journey, posts an update; A features it as a Happy tail; B reviews A and A replies; separately B becomes a foster volunteer and offers to foster a pet A marked as needing a foster.
