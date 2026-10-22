# PawFinder: Full Product Spec & Implementation Plan

A production-grade SwiftUI pet adoption platform. Adopters discover pets through browse, swipe, and personalized recommendations; save and compare favorites; find shelters on a map; identify breeds with on-device ML; apply to adopt; and message shelters. Everything syncs across devices, with notifications, widgets, and Live Activities.

This document replaces the earlier basic MVP plan. It is organized as **release tiers** (v1.0 / v1.5 / v2.0) so the app is shippable at each step, but the end state is a full-featured app.

---

## 1. Vision & Goals

**Vision:** the best native iOS experience for finding and adopting a pet, from first browse to "application approved".

**Goals**
- A discovery experience that feels better than the shelters' own websites
- Offline-first reliability
- Real two-sided value: adopters get tools, shelters get qualified, informed applicants
- An engineering showcase: modular architecture, on-device ML, sync, system integrations, CI/CD

**Non-goals (for now):** payments or adoption fees in-app, veterinary telehealth, Android or web clients.

---

## 2. Target Platforms & Tech Stack

| Area | Choice |
|---|---|
| Min OS | iOS 17 (adopt iOS 26 features behind `#available`) |
| UI | SwiftUI, Observation (`@Observable`), SwiftUI `Map`, Swift Charts (optional) |
| Architecture | Modular MVVM + Repository + Use Cases, Swift Package Manager modules |
| Concurrency | Swift Concurrency (async/await, actors, `AsyncStream`), strict concurrency on |
| Networking | `URLSession` + `Codable`, typed endpoints, retry/backoff, ETag/caching |
| Local persistence | Core Data (offline cache, favorites, drafts, outbox) |
| Cloud/backend | Firebase (Auth, Firestore, Storage, Cloud Functions) *or* Supabase; see §4 |
| Sync | Firestore listeners for user data; optional `NSPersistentCloudKitContainer` for private data |
| Push | APNs via FCM or direct; Notification Service Extension for rich notifications |
| ML | Create ML / Core ML, Vision, Natural Language; optional Foundation Models (iOS 26) |
| Maps/location | MapKit, CoreLocation, geofencing (optional) |
| System integration | WidgetKit, ActivityKit (Live Activities), App Intents, Spotlight (CoreSpotlight), Share Sheet, Universal Links |
| Images | Custom disk/memory cache with downsampling |
| Analytics/crash | Firebase Analytics + Crashlytics (or TelemetryDeck + Sentry) |
| Testing | XCTest, Swift Testing, XCUITest, snapshot tests, `URLProtocol` stubs |
| CI/CD | GitHub Actions + fastlane, TestFlight automation |

---

## 3. Feature Inventory

### 3.1 Discovery
- Browse grid/list with infinite scroll and skeleton loading
- Rich search (text, breed autocomplete), multi-facet filters: species, breed, age, size, gender, color, coat length, good with kids/dogs/cats, house-trained, special needs, distance, time in shelter
- **Saved searches** with alert toggles
- **Swipe mode** (card stack): like, pass, super-like; undo last
- **Compare mode:** side-by-side attributes for 2–3 pets
- **Recently viewed** history
- **"Longest waiting"** and **"Urgent / foster needed"** curated rails
- Personalized **For You** feed (see §3.7)

### 3.2 Pet Detail
- Photo carousel with zoom, video support, share
- Attributes, temperament tags, medical info, adoption fee, shelter info
- Embedded mini-map and distance
- **Compatibility score** based on the user's lifestyle profile
- Similar pets rail
- Actions: favorite, apply, message shelter, call/email, share, report listing

### 3.3 Favorites & Collections
- Favorites with offline snapshots
- Custom **collections** (e.g., "Dogs for apartment", "Maybe later")
- Notes per pet
- Status tracking: "Still available / Pending / Adopted" with change notifications

### 3.4 Shelters & Map
- Map with clustering, filter chips, "Search this area"
- Shelter profile page: bio, hours (with open-now), photos, current pets, volunteer and donation links
- Directions (Apple Maps), call, website
- Follow shelters; get notified of new arrivals

### 3.5 Breed Identification (Core ML)
- Photo-library and camera capture
- **Live camera mode:** real-time classification overlay
- Top-K predictions with confidence, breed info cards (temperament, size, lifespan, care needs)
- "Mixed breed" handling: show top blend candidates with percentages
- "Find adoptable [breed]" deep link into search
- Pet detection pre-check (reject non-pet images)
- History of past identifications

### 3.6 Adoption Workflow
- Adopter profile (household, home type, other pets, experience, schedule)
- In-app **adoption application** with draft autosave, validation, and attachments
- Application tracker with statuses: Submitted → In Review → Interview → Approved/Declined → Adopted
- **Live Activity** and push notifications on status changes
- Schedule a **meet-and-greet** (calendar integration via EventKit)
- Adoption checklist (supplies, vet, microchip) once approved

### 3.7 Personalization & Intelligence
- Lifestyle questionnaire, then a **compatibility** ranking
- Implicit signals (views, likes, passes, dwell time) feed an on-device recommender
- On-device **pet description summarizer** and "Is this a good match for me?" explainer (Foundation Models, iOS 26, with graceful fallback)
- Natural-language search ("calm senior cat good with kids") parsed to filters

### 3.8 Messaging
- 1:1 chat between adopter and shelter, tied to a pet listing
- Text + image messages, read receipts, typing indicators (optional)
- Push notifications, unread badges
- Report/block and basic moderation hooks

### 3.9 Notifications
- New pets matching saved searches
- Favorite pet status changes
- Application updates and message replies
- New arrivals from followed shelters
- Per-category preferences, quiet hours

### 3.10 Account & Settings
- Sign in with Apple (required if offering other social logins), email, optional Google
- Profile, avatar, lifestyle preferences
- Notification, privacy, and units settings
- Data export and **account deletion** (App Store requirement)
- Appearance, language, clear cache

### 3.11 Pet Care Hub
- Breed guides, first-week checklist, adoption prep guides
- Curated articles (remote-config driven, cached)
- Supply checklist with check-off persistence

### 3.12 System Integrations
- **Widgets:** Favorite pet, Pet of the day, Application status
- **Live Activities:** application progress
- **App Intents / Siri / Shortcuts:** "Show dogs near me", "Identify this pet"
- **Spotlight** indexing of favorites
- **Universal links** to pets and shelters; Share extension ("Save to PawFinder")
- **Handoff** between iPhone and iPad

---

## 4. Backend Strategy

### Data sources
1. **Public adoptable-pet APIs** (Petfinder v2 or RescueGroups) are the read-only source of listings and organizations.
2. **Your own backend** stores users, favorites, applications, chats, and alerts. Public APIs don't provide these.

### Backend options

| Option | Pros | Cons |
|---|---|---|
| **Firebase** (Auth, Firestore, Storage, Functions, FCM) | Fastest to ship, realtime listeners for chat, good iOS SDK | Vendor lock-in, query limits |
| **Supabase** (Postgres, Auth, Realtime, Storage) | SQL, row-level security, open source | Smaller iOS ecosystem |
| **CloudKit** | No server, native, free | Poor for cross-user features like chat; Apple-only |
| **Vapor (Swift server)** | One language end to end, full control | You operate it |

**Recommendation:** Firebase (or Supabase) for accounts, applications, and chat. Use a **thin proxy/Cloud Function** in front of the public pet API so the API secret never ships in the app, and so you can cache and normalize listings.

### Cloud Functions to build
- `syncListings`: scheduled job pulling and normalizing listings, detecting status changes
- `matchSavedSearches`: fan-out push notifications for new matches
- `onApplicationStatusChange`: push and Live Activity update
- `onMessageCreate`: push notification to the recipient
- `deleteUserData`: account deletion pipeline

### Shelter side (scope decision)
- **v1:** simulate or seed shelter responses (admin console or Firebase console) so the adopter flow can be demonstrated end to end.
- **v2 (optional):** a lightweight shelter web dashboard or iPad app to manage listings, applications, and chats.

---

## 5. Architecture

### Layering

```
SwiftUI View
   └─ ViewModel (@Observable, @MainActor)
        └─ Use Case (single-purpose business logic)
             └─ Repository (protocol)
                  ├─ Remote data source (API / Firebase)
                  └─ Local data source (Core Data)
```

### Module layout (Swift Packages)

```
PawFinder (app target: composition root only)
Packages/
├── DesignSystem        # colors, typography, components, haptics, icons
├── Core                # extensions, logging, feature flags, error types
├── Networking          # APIClient, Endpoint, auth interceptor, retry
├── Persistence         # Core Data stack, entities, migrations
├── Domain              # models, repository protocols, use cases
├── Data                # repository implementations, DTOs, mappers
├── Location            # LocationService, geocoding, geofencing
├── ML                  # BreedClassifier, recommender, NL parsing
├── Auth                # session, Sign in with Apple, token storage (Keychain)
├── Messaging           # chat models, listeners, outbox
├── Features
│   ├── Discover
│   ├── Swipe
│   ├── PetDetail
│   ├── Favorites
│   ├── Map
│   ├── Identify
│   ├── Applications
│   ├── Chat
│   ├── Profile
│   ├── CareHub
│   └── Onboarding
└── TestSupport         # mocks, fixtures, in-memory stores
```

Benefits: faster incremental builds, enforced dependency direction, and each feature can be run in its own preview app.

### Key patterns
- **Dependency injection** via an `AppEnvironment` container plus `@Environment`; protocols for every service
- **Offline-first:** UI reads from Core Data, and the network updates the store (single source of truth)
- **Outbox pattern:** writes made offline (favorites, applications, messages) queue and retry
- **Navigation:** per-tab `NavigationStack` with typed `Route` enums and a deep-link router
- **Feature flags / remote config** for staged rollout
- **Error model:** typed `AppError` with user-presentable messages and recovery actions

---

## 6. Data Model

### Domain entities
- `User`, `AdopterProfile`
- `Pet`, `PetMedia`, `PetAttributes`
- `Shelter`, `ShelterHours`
- `Favorite`, `Collection`, `PetNote`
- `SavedSearch`, `SearchFilters`
- `Application`, `ApplicationStatusEvent`
- `Conversation`, `Message`
- `BreedInfo`, `BreedPrediction`, `IdentificationRecord`
- `NotificationPreference`
- `Article`, `ChecklistItem`

### Core Data (local cache and offline store)
- `PetEntity`, `ShelterEntity`, `FavoriteEntity`, `CollectionEntity`
- `SavedSearchEntity`, `ApplicationDraftEntity`
- `MessageEntity`, `ConversationEntity`, `OutboxItemEntity`
- `IdentificationEntity`, `RecentlyViewedEntity`
- Unique constraints on remote IDs, `cachedAt` timestamps, and lightweight migrations from day one

### Cloud (Firestore/Postgres) collections
`users`, `favorites`, `collections`, `savedSearches`, `applications`, `conversations/{id}/messages`, `deviceTokens`, `reports`

### Security rules
Users can only read and write their own documents. Conversations are readable only by their participants. Applications are readable only by the applicant (and the shelter, once that exists).

---

## 7. Screen Inventory & Navigation

**Tabs:** Discover · Map · Identify · Favorites · Profile

```
Onboarding → (Sign in / Skip) → Lifestyle questionnaire → Location permission → Home
Discover → Search → Filters → Saved Searches
        → Pet Detail → Apply → Application Form (multi-step) → Confirmation
                    → Chat with Shelter
                    → Shelter Profile → Shelter pets
        → Swipe Mode · Compare
Map → Shelter pin card → Shelter Profile
Identify → Camera / Live / Library → Results → Breed Info → Find adoptable
Favorites → Collections → Pet Detail
Profile → Applications → Application Detail (timeline)
        → Messages → Chat
        → Settings → Notifications · Privacy · Account deletion
        → Care Hub → Articles · Checklists
```

---

## 8. Implementation Phases

Estimates assume ~10–15 hours/week. Each phase ends with a demoable build. **Reorder phases 8–14 freely** based on what you want to showcase.

### Phase 0: Foundation & Tooling (1 week)
- [ ] Repo, `.gitignore`, `.xcconfig` secrets handling, branch strategy
- [ ] Xcode project plus SPM module skeleton (§5)
- [ ] Design system: color tokens, typography, spacing, `PFButton`, `PFCard`, `PFChip`, empty/error/loading views
- [ ] Dependency container, logging (`os.Logger`), feature flags
- [ ] SwiftLint/SwiftFormat, GitHub Actions: build and test on PR
- [ ] Tab shell with typed navigation and the deep-link router skeleton

### Phase 1: Networking & Data Layer (1–1.5 weeks)
- [ ] `APIClient` (generic, typed `Endpoint`, interceptors, retry/backoff, cancellation)
- [ ] OAuth token provider (or proxy auth) with actor-isolated refresh
- [ ] DTOs, mappers, and fixtures; `MockPetRepository` plus `RemotePetRepository`
- [ ] Core Data stack with a cache-then-network policy and a staleness policy
- [ ] Pagination abstraction (cursor/page)
- [ ] Unit tests for decoding, mapping, and error paths

### Phase 2: Discovery Core (1.5 weeks)
- [ ] Pet grid/list, skeleton loading, pagination, pull-to-refresh
- [ ] Image pipeline: downsampling, memory and disk cache, prefetching
- [ ] Search with debounce, breed autocomplete
- [ ] Filter sheet with all facets, active chips, and persisted filters
- [ ] Curated rails (Longest waiting, New today)
- [ ] Recently viewed tracking

### Phase 3: Pet Detail (1 week)
- [ ] Carousel with zoom and video, attribute chips, expandable text
- [ ] Shelter card, mini-map, distance
- [ ] Share (`ShareLink`), universal link generation
- [ ] Similar pets rail
- [ ] Report listing flow

### Phase 4: Favorites, Collections & Offline (1.5 weeks)
- [ ] Favorite toggle with optimistic UI and an animated heart
- [ ] Collections CRUD, notes, drag to reorder
- [ ] Offline snapshots and "status changed" detection
- [ ] Outbox for offline mutations
- [ ] Spotlight indexing of favorites
- [ ] Unit and integration tests with in-memory stores

### Phase 5: Location, Map & Shelters (2 weeks)
- [ ] `LocationService` (async stream, auth states, accuracy handling)
- [ ] Shelter repository with geocoding and caching
- [ ] Map: clustering, filter chips, selected card, "Search this area"
- [ ] Shelter profile (hours with open-now logic, current pets, follow button)
- [ ] Directions via `MKMapItem`
- [ ] Manual location (ZIP/city) fallback when permission is denied

### Phase 6: Core ML Breed Identification (2–3 weeks)
- [ ] Dataset curation: Oxford-IIIT Pet (37) and/or Stanford Dogs (120) plus cat breeds
- [ ] Train with Create ML (or transfer learning in PyTorch and convert); record accuracy, confusion matrix, and model card
- [ ] `BreedClassifier` actor: Vision request, top-K, off-main inference
- [ ] Pet pre-detector (reject non-pet images)
- [ ] Photo library and camera capture; results UI with confidence bars
- [ ] **Live camera mode** with `AVCaptureSession` and frame throttling
- [ ] Mixed-breed presentation, breed info cards, history
- [ ] "Find adoptable [breed]" deep link into Discover
- [ ] Performance benchmarks (latency, memory, thermal) and model size budget

### Phase 7: Auth & Accounts (1.5 weeks)
- [ ] Sign in with Apple, email/password, and optional Google
- [ ] Session management with Keychain token storage and silent refresh
- [ ] Guest mode that migrates to an account on sign-in (local favorites merge)
- [ ] Profile editing and avatar upload
- [ ] Account deletion flow plus a data export request
- [ ] Onboarding and lifestyle questionnaire

### Phase 8: Cloud Sync (1.5 weeks)
- [ ] Sync favorites, collections, notes, saved searches, and profile
- [ ] Conflict resolution (last-writer-wins with tombstones)
- [ ] Offline-to-online reconciliation and a sync status indicator
- [ ] Multi-device testing (iPhone and iPad/simulator)

### Phase 9: Adoption Application Workflow (2–3 weeks)
- [ ] Adopter profile screens (household, home type, pets, experience)
- [ ] Multi-step application form with validation and autosaved drafts
- [ ] Attachments (ID, lease, vet reference photos) with upload progress
- [ ] Submission, confirmation, and application tracker timeline
- [ ] Cloud Function for status transitions, plus a simulated shelter responder or admin tool
- [ ] **Live Activity** for application status
- [ ] Meet-and-greet scheduling with EventKit
- [ ] Post-approval adoption checklist

### Phase 10: Messaging (2 weeks)
- [ ] Conversation list and chat UI (bubbles, image messages, read receipts)
- [ ] Realtime listeners, pagination of history, and an offline outbox
- [ ] Unread badges, report/block, and moderation hooks
- [ ] Notification Service Extension for rich previews

### Phase 11: Notifications & Saved Search Alerts (1.5 weeks)
- [ ] APNs registration, device token management, permission priming screen
- [ ] Backend fan-out for saved searches, favorite status changes, and followed shelters
- [ ] Notification preference center and quiet hours
- [ ] Deep links from notification taps into the right screen
- [ ] Badge count management

### Phase 12: Personalization & On-Device Intelligence (2 weeks)
- [ ] Compatibility scoring (questionnaire to pet attributes)
- [ ] Signal capture (view, like, pass, dwell) stored locally
- [ ] On-device recommender (start rule-based, then a Create ML tabular model), feeding the **For You** feed
- [ ] Natural-language search: Natural Language framework or Foundation Models to parse queries into `SearchFilters`
- [ ] Optional: AI summary and "why this match" explanation (iOS 26, guarded by availability)
- [ ] Evaluate with offline metrics and a simple A/B flag

### Phase 13: Swipe, Compare & Care Hub (1.5–2 weeks)
- [ ] Swipe card stack with gestures, haptics, undo, and prefetching
- [ ] Compare view (2–3 pets, highlighted differences)
- [ ] Care Hub: remote-config articles with caching, breed guides, and persisted checklists

### Phase 14: Platform Integrations (2 weeks)
- [ ] WidgetKit: favorite pet, pet of the day, and application status (App Group shared store)
- [ ] App Intents plus Shortcuts: search pets, identify from a photo, open favorites
- [ ] Share extension ("Save to PawFinder")
- [ ] Universal links and Handoff
- [ ] Optional: iPad split-view layout (`NavigationSplitView`)

### Phase 15: Quality, Accessibility, Security & Performance (2 weeks)
- [ ] VoiceOver audit, Dynamic Type (up to the accessibility sizes), reduced motion, contrast
- [ ] Localization via String Catalogs (English plus one more language to prove the pipeline)
- [ ] Performance: Instruments passes (Time Profiler, Allocations, Leaks), launch-time budget, scroll hitch checks
- [ ] Security: Keychain for tokens, certificate pinning (optional), jailbreak-agnostic hardening, input validation, privacy manifest
- [ ] Snapshot tests for design-system components; UI tests for critical flows
- [ ] Crash reporting and analytics events wired (§10)

### Phase 16: Release Engineering & Launch (1.5 weeks)
- [ ] fastlane lanes: test, beta, release; GitHub Actions to TestFlight
- [ ] App Store assets, privacy policy, and nutrition labels (location, camera, identifiers, messages)
- [ ] TestFlight beta with 10+ testers; triage feedback
- [ ] Review-compliance checklist (§11)
- [ ] Portfolio packaging: README, architecture diagrams, demo video, ML model card, case study write-up

### Added after the lister/real-chat refactor (Phases 17–20)

These four phases were added once the app had two real personas (adopter, lister) on Firestore. Phases 17 and 18 are **built** (not compiled yet); 19-20 are **planned, not built**. They are listed in the order to build them. The same scope rules apply: Firebase free (Spark) plan only, no server, no tests, no Storage (photos stay inline in Firestore), new access rules go in `firestore.rules` (and need re-publishing), and docs are updated per phase (Leftover.md, CLAUDE.md, Listers-and-Messaging.md). Phase 6 (Core ML) is still deferred, on purpose.

### Phase 17: Meet & Greet Planner (MapKit) (~1 week) **(built; not compiled yet. See Leftover.md)**
The app's one full MapKit feature. Today's map (`ShelterMapView`) only shows lister pins; this phase makes it do real work for both personas.
- [x] **Place picker** (lister, and adopter when counter-proposing): full-screen map with search-as-you-type (`MKLocalSearchCompleter`), a draggable pin, reverse geocoding for the address, and shortcut chips ("Dog parks", "Cafés", "Vets") through `MKLocalSearch`
- [x] **Meet-up proposal in chat:** a special message type (`kind: "meetup"`: place name, address, lat/lon, proposed date and time, status `proposed/accepted/declined/changed`). Both sides see a card with a mini map; accept, decline, or propose another spot; the card updates live. Optional: copy the accepted meeting into the application's timeline
- [x] **Route and ETA:** `MKDirections` with a polyline overlay, a driving / walking / transit picker, travel time and distance, and **Open in Apple Maps** (`MKMapItem.openMaps`) for turn-by-turn
- [x] **Look Around** preview (`LookAroundPreview` / `MKLookAroundSceneRequest`) for the meeting spot where Apple has coverage; hidden when it doesn't
- [x] **Discover map upgrade:** one pin per listing (pet-photo marker, not one pin per lister), **clustering** when zoomed out, a **radius circle** (`MapCircle`) matching the Discover distance filter, tap a pin for a callout that opens the pet
- [x] **Nearby vets and pet stores** (`MKLocalSearch`, point-of-interest filter) on the Care Hub, and on the "Welcome home" screen after an adoption
- [x] A reminder (local notification, no EventKit) for an accepted meet-up, one hour before
- [x] Plumbing: `ChatMessage` gets optional `kind`/`meetup` fields (old messages unaffected); `firestore.rules` allows only the two participants to create or update meet-up messages; no new indexes; coordinates are stored as plain numbers
- Out of scope: live location sharing, geofencing, offline map tiles

### Phase 18: Lister Reviews (~0.5–1 week) **(built; not compiled yet. See Leftover.md)**
- [x] After an application reaches **adopted**, the adopter can rate the lister (1–5 stars) with an optional short note. One review per application, editable for 7 days
- [x] Reviews collection `reviews/{applicationID}` (listerID, reviewerID, reviewerName, rating, text, createdAt). Rules: only the adopter of an *adopted* application may create; anyone can read (profiles are public); the lister can't edit or delete (they can report)
- [x] Lister profile and `ShelterCard` show the average rating and review count; a "Reviews" list screen with newest first
- [x] Aggregate kept on the lister's `users/{uid}` doc (`ratingSum`, `ratingCount`, updated in the same batch with `FieldValue.increment`) so lists never read every review
- [x] Lister can report an unfair review (reuses the existing `reports` collection)
- [x] Shown as a prompt on the "Welcome home" screen and from the application detail screen
- Out of scope: lister replies to reviews, verified-purchase style checks, review photos

### Phase 19: Adoption Journey (~1 week)
What happens after "adopted". Gives both personas a reason to come back.
- [ ] **Journey screen** (adopter) for an adopted pet: a timeline of Day 1 / Week 1 / Month 1 / Month 3 check-ins, each with a short checklist drawn from the existing Care Hub guides
- [ ] **Post an update:** the adopter can post a photo and a short note to the journey (one photo each, compressed like chat photos, inline in Firestore: `journeys/{applicationID}/updates/{id}`)
- [ ] **Lister sees the updates** on the application, and can choose to feature one on their profile ("Happy tails"); the adopter can switch sharing off
- [ ] Local notifications for the next check-in date (reuses `NotificationManager.deliver`, adds a "journey" category and preference switch)
- [ ] Journey progress shown on the Profile tab and on the adopted pet's card in My applications
- [ ] Rules: only the adopter and that listing's lister can read a journey; only the adopter can write updates; "Happy tails" updates are readable by everyone signed in
- Out of scope: vet-record uploads, return/re-homing flow, video updates

### Phase 20: Foster Volunteers (~1–1.5 weeks)
A third persona on the same login, alongside adopters and listers.
- [ ] **Foster profile:** a "Become a foster" section in Profile (toggle `isFoster` on `users/{uid}`; fields: species and sizes you can take, how many animals, how long (days/weeks/open-ended), home type, other pets, experience, city and coordinates)
- [ ] **Needs foster:** a lister can mark a listing as "Needs a foster" (new `fosterNeeded` flag, with a reason and duration). Shows as a badge on the pet card and detail screen and as a Discover filter
- [ ] **Foster directory:** a list and a map layer (reuses Phase 17 map code) of volunteers near you, visible to listers only; fosters can hide themselves at any time
- [ ] **Offer to foster:** a foster can message a lister about a "needs foster" listing (reuses chat) or send a short offer that the lister accepts or declines (small `fosterOffers/{id}` collection, with status updates and notifications)
- [ ] When accepted, the listing shows "In foster care with <name>" (the foster's public name only, no address) until it is adopted
- [ ] Rules: a foster's address is never public, only the city; lister-only directory reads; offers are readable by the two people involved
- Out of scope: background checks, foster agreements and documents, supply or donation tracking, stipends

### Phase dependencies and order
Build **17 → 18 → 19 → 20**. 18 and 19 hang off the application reaching "adopted", which already exists. 20 reuses the map code from 17 and the chat from Phase 10. None of them need Phase 6, 8, or 12.

---

## 9. Release Tiers

### v1.0: Shippable Core (Phases 0–7)
Discovery, detail, favorites and collections, map and shelters, breed ID (photo and live), accounts, and onboarding.

### v1.5: Engagement (Phases 8–11, 13)
Sync, adoption applications, messaging, notifications and alerts, swipe, compare, and Care Hub.

### v2.0: Intelligence & Ecosystem (Phases 12, 14–16)
Personalization, NL search, widgets, Live Activities, App Intents, iPad layout, and full polish.

**Total estimate:** roughly 5–7 months part-time (full-time: ~2.5–3.5 months).

**Fastest path to a strong portfolio piece:** Phases 0–6 → 7 → 9 (applications) → 14 (widgets and Live Activity) → 15–16. Skip messaging and personalization if time is short.

---

## 10. Analytics & Observability

**Key events:** `app_open`, `pet_viewed`, `pet_favorited`, `search_performed`, `filter_applied`, `swipe_action`, `breed_identified` (confidence bucket, latency), `application_started` / `_submitted`, `message_sent`, `notification_opened`, `permission_result`

**Funnels:** browse → detail → favorite → apply → approved

**Health:** crash-free sessions, API error rates by endpoint, ML latency percentiles, sync failure rates, cold start time

**Privacy:** no PII in analytics, opt-out toggle, and a minimal ATT-free setup (no cross-app tracking)

---

## 11. App Store & Compliance Checklist

- Sign in with Apple offered whenever third-party sign-in exists
- In-app **account deletion**
- Privacy manifest and accurate privacy nutrition labels
- Clear permission purpose strings (location, camera, notifications)
- User-generated content safeguards (chat): report, block, and a content policy
- Content moderation process documented
- Terms of Service and Privacy Policy links in-app
- Attribution/ToS compliance for the pet data provider (check API terms; cache limits and "powered by" requirements)
- ML disclosures: on-device processing, no photo upload (a strong privacy selling point)

---

## 12. Testing Strategy

| Layer | Approach |
|---|---|
| Domain/use cases | Pure unit tests, table-driven |
| Repositories | Stubbed API (`URLProtocol`) plus in-memory Core Data |
| ViewModels | State-transition tests with mock repositories |
| ML | Golden-image tests, threshold regression, latency budget tests |
| Sync/outbox | Simulated offline/online sequences, conflict cases |
| UI | XCUITest for: onboarding, browse to favorite, filter, identify, apply, chat |
| Snapshot | Design-system components in light/dark and large Dynamic Type |
| Manual QA | Airplane mode, flaky network, permission denial, low storage, background/foreground, multi-device |

**Coverage targets:** ≥80% for Domain/Data/ML packages; critical user flows covered by UI tests.

---

## 13. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Scope is very large | Strict release tiers; every phase ends demoable; cut order defined in §9 |
| Public API rate limits/ToS limits | Proxy and cache via Cloud Functions; normalize into your own store; keep mock mode |
| No real shelter counterpart for applications/chat | Simulated shelter responder and admin console; clearly label as demo if unpublished |
| ML accuracy and bias | Transfer learning, balanced data, confidence thresholds, honest UX copy, published model card |
| Sync conflicts/data loss | Tombstones, versioned writes, idempotent outbox, sync tests |
| Chat abuse/moderation | Report/block, rate limits, server-side rules, content policy |
| Push reliability | Retry/dedupe on the server, token cleanup, deep-link fallbacks |
| Build times with many modules | Keep packages cohesive; use previews per feature; CI caching |
| Privacy/compliance rejection | Follow §11 early; do a pre-submission review in Phase 15 |

---

## 14. Engineering Conventions

- **Branching:** `main` is always releasable; `feature/<phase>-<name>`; PR per feature with screenshots/GIF
- **Commits:** Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`)
- **Code review checklist:** loading/empty/error states, accessibility labels, dark mode, Dynamic Type, tests, no force-unwraps, strict-concurrency clean
- **Definition of Done:** builds with zero warnings; tests added and passing; accessibility checked; analytics event added where relevant; reviewed on a physical device
- **ADRs:** keep short Architecture Decision Records (backend choice, sync strategy, ML approach) in `/docs/adr`

---

## 15. Stretch & Future Ideas

- Shelter-side iPad app or web dashboard
- Foster and volunteer matching
- Lost and found pets with geofenced alerts
- Adoption success stories feed
- Apple Watch companion (new pet alerts)
- Vision-based pet attribute tagging (color/coat) for auto-filling listings
- visionOS gallery of favorites
- Donations via Apple Pay to shelters
- Multi-language rollout and regional data sources

---

## 16. Portfolio Narrative

- **Architecture:** modular SPM, Clean-style layering, protocol-driven DI, offline-first with an outbox
- **Modern Swift:** strict concurrency, actors, `@Observable`, Swift Testing
- **On-device ML:** custom-trained breed classifier, live camera inference, on-device recommender, and optional on-device LLM features, all privacy-preserving
- **Systems depth:** auth, realtime chat, push, sync and conflict resolution, background work
- **Platform polish:** widgets, Live Activities, App Intents, Spotlight, and universal links
- **Engineering maturity:** CI/CD with fastlane, analytics funnels, accessibility audit, performance budgets, and compliance checklist

---

*Start with Phase 0 and the design system. A consistent look and a solid module skeleton make every later phase faster.*
