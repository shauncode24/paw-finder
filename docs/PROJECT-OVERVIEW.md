# PawFinder: what it does, end to end

PawFinder is a native iOS app (SwiftUI, iOS 17+) where **people and rescues list pets for adoption** and **adopters find, talk to, apply for and follow up on those pets**. Everything is shared live between phones through Firebase's free plan. There is no server of our own.

> **Status:** the code was written on Windows and **has never been compiled**. Expect a round of small compile fixes on the first Mac build (see [SETUP.md](SETUP.md)). Nothing here has been tested on a device.

---

## 1. The three roles (one account, no separate logins)

| Role | Who | What they do |
|---|---|---|
| **Adopter** | Anyone (guests can browse) | Find pets, favorite, chat, apply, meet, adopt, follow the pet's first months, review the lister |
| **Lister** | An individual or a rescue; becomes one by saving a lister profile | Post pets, answer chats and applications, plan meet-ups, mark pets adopted, find foster volunteers |
| **Foster volunteer** | Anyone who saves a foster profile | Offer to foster pets that need a home for a while |

A person can be all three at once. Guests can browse and favorite; an account is needed to message, apply, list, review or foster.

---

## 2. The story of one pet, start to finish

1. **A lister posts the pet.** Profile › "List a pet for adoption" asks once for a short lister profile, then a form: up to 5 photos, breed (with suggestions), age, size, coat, temperament, how the pet gets on with kids/dogs/cats, health, adoption fee, the story, location, and optional video link. They can mark it **"needs a foster"**.
2. **It appears everywhere within seconds.** Discover (grid or list), the pet map, rails like "New today", and followed-lister alerts.
3. **An adopter finds it.** Search (name, breed, temperament, colours, story, place), filters (age, size, gender, good with kids/dogs/cats, house-trained, special needs, coat, time listed, needs a foster, distance), sort, saved searches with alerts, swipe mode, and a breed-match quiz in the Breeds tab. They favorite it, add notes and collections, compare pets side by side, or share it.
4. **They talk.** "Message" opens a real chat with the lister: live messages, typing indicator, Sent/Read, up to 4 photos at a time, report and block, offline outbox.
5. **They plan a meet & greet.** Either person taps 📍 in the chat, searches for a spot (or picks a dog park, café, vet), chooses a time, and sends a proposal card. The other accepts, declines or suggests something else. Accepted meet-ups show a route with travel time (drive/walk/transit), "leave by" time, a street-view preview, and get a reminder an hour before.
6. **They apply.** A multi-step application (pre-filled from the adopter's lifestyle answers, with optional ID/lease photos that stay on the phone). The lister sees it under "Applications received" and moves it through *In review → Interview → Approved/Declined*. The adopter sees each change live and gets a notification. Approving marks the listing "pending".
7. **They adopt.** Either side marks it adopted; the listing leaves Discover. A celebration screen offers confetti, sharing, "Rate the lister" and "Find a vet nearby".
8. **The journey begins.** The adopter gets a page for the pet with check-ins at **Day 1, Week 1, Month 1 and Month 3** (short checklists linked to Care Hub guides, reminders on the dates) and a feed of photo updates the lister can see.
9. **Happy tails and reviews.** If the adopter allows it, the lister can feature an update on their profile as a "Happy tail". The adopter can rate the lister (1-5 stars and a note); the lister can reply publicly.
10. **Fostering, if needed.** For a pet marked "needs a foster", volunteers offer to help; the lister accepts one (the pet then reads "In foster care with <name>") or invites volunteers from a directory.

---

## 3. Screens and features by area

### Browse and decide
- **Discover:** grid/list toggle, rails, search, filter sheet, sort, "Nearest" with location or a typed postcode, saved searches (with alerts), shimmer placeholders, offline banner.
- **Pet page:** photo carousel with zoom, facts, health, fee, good-with answers, video link, lister card (rating, contact, distance), similar pets, report, share, Handoff, "Compare with similar pets".
- **Favorites tab:** notes, collections, reorder, status-change badges (adopted/pending/removed), offline photos, Spotlight search, compare.
- **Swipe mode:** like / pass / super-like with undo and haptics.
- **Breeds tab:** lifestyle-based breed match quiz and breed browser. Care Hub: guides, breed guides ("Find adoptable [breed]"), checklists, vets and pet shops near you.

### Maps
- **Map tab › Pets:** each pet is a round photo pin; pins merge into numbered bubbles; a circle shows the distance filter; tapping a pin opens a card. **Listers:** the lister map with "open now", follow, and a list view.
- **Meet & Greet** (place picker, route, Look Around), **Near you** (vets, pet stores, dog parks, groomers).

### Lister tools
- Lister profile (person or organisation), My listings (edit, pending/adopted/available, delete), Applications received with status buttons, reviews and replies, the journey feed, foster offers and the foster directory.

### Accounts and settings
- Email or username + password, Sign in with Apple (button present; needs a paid Apple account to switch on), email verification, change password, password reset by email, export my data, delete account (removes listings, profile and foster profile).
- Settings: theme, **km/mi**, notification categories and quiet hours, erase local data. Help & FAQ, privacy, terms, About.

### Notifications (all local, no push server)
Messages, application updates, new applications, favorite status changes, new pets from followed listers, saved-search matches, meet-up reminders, journey check-ins, foster offers. They appear while the app is open, or when iOS runs its background refresh. The app-icon badge counts unread chats, new applications, foster offers and changes.

### System integration
Siri/Shortcuts (App Intents), Spotlight, Handoff, `pawfinder://` deep links (pets, chats, applications, journeys, foster offers).

---

## 4. How it is built

```
SwiftUI views  →  @Observable stores/services  →  Firebase (Auth + Firestore, free plan)
```

- **Folders:** `App/` (app entry, router, tab bar), `Screens/` (one folder per area), `DesignSystem/` (colours, buttons, cards, states), `Models/`, `Services/`.
- **Navigation:** one `NavigationStack` per tab, driven by a typed `Route` enum and a `Router` (also handles deep links and notification taps).
- **State:** `@Observable` classes passed through `.environment(...)`: `AuthManager`, `ListingsService`, `MessagesStore`, `ApplicationsStore`, `FosterStore`, `FavoritesStore`, `ProfileStore`, `ListerProfileStore`, `LocationService`, and others.
- **Real-time without a server:** Firestore snapshot listeners act as the "socket". Writes made offline are queued by Firestore and sent on reconnect.
- **Photos live inside Firestore documents** as small base64 JPEGs (no paid Storage). A private `pfphoto:` URL scheme and `PhotoLoader` keep screens simple.
- **Search/filter/sort run on the phone** over one live feed of active listings (newest 500), so no Firestore indexes are needed and reads stay cheap.
- **Local data** (UserDefaults/JSON files): favorites, collections, notes, saved searches, followed listers, application drafts and attachments, recently viewed, journey check-in ticks, notification preferences.
- **Security rules** ([firestore.rules](../firestore.rules)) decide who can read/write each collection.

### What is stored in Firestore
| Collection | What | Who can read |
|---|---|---|
| `users/{uid}` | Lister profile and rating totals | Everyone |
| `listings/{id}` (+ `photos`) | Pets | Everyone |
| `conversations/{id}` (+ `messages`) | Chats, meet-up proposals | The two people |
| `applications/{id}` | Adoption applications | Adopter and lister |
| `reviews/{applicationId}` | Lister reviews and replies | Everyone |
| `journeys/{applicationId}` (+ `updates`) | Post-adoption journey | Adopter and lister |
| `happyTails/{updateId}` | Updates a lister features | Signed-in people |
| `fosters/{uid}` | Foster volunteer profile (city only) | The volunteer and listers |
| `fosterOffers/{id}` | Offers to foster | The two people |
| `reports/{id}` | Reports of listings, chats, reviews | Write-only from the app |

---

## 5. What was built, in order

| Phase | Result |
|---|---|
| 0-5 | Project setup, design system, Discover, pet page, favorites/collections/offline, location and map |
| 7 | Accounts (email, username, Apple), profile, lifestyle questionnaire |
| 9-11 | Applications, messaging, notifications and saved-search alerts |
| 13-14 | Swipe, compare, Care Hub, App Intents, Handoff |
| Scope bump + additions | Onboarding, Breeds hub, settings, FAQ, polish ([Additions.md](Additions.md)) |
| **Pivot** | Petfinder API removed; users post listings; real chat on Firestore ([Listers-and-Messaging.md](Listers-and-Messaging.md)) |
| 17 | Meet & Greet planner (MapKit) |
| 18 | Lister reviews |
| 19 | Adoption journey and Happy tails |
| 20 | Foster volunteers |
| Leftover pass | km/mi, richer search, email verification, change password, multi-photo chat, review replies, auto-decline foster offers |

Skipped on purpose: **Phase 6 Core ML** (do later), Phase 8 cross-device sync, Phase 12 personalization, widgets/extensions, and anything needing push, Cloud Functions or a paid plan ([Leftover.md](Leftover.md)).

---

## 6. Honest limits

- **Never compiled or run.** Rules untested. Treat everything as a first draft until it builds.
- **No push when the app is closed.** Alerts depend on iOS's background refresh.
- **Rules are "good enough", not hardened.** Anyone can become a lister; no vetting; fake adoptions or reviews are possible; reports have no moderator screen.
- **Free-plan size limits:** 5 small photos per listing, 500 listings in the feed, about 1,000 listings of storage.
- **No tests, no CI.**
- **Sign in with Apple** is switched off until a paid Apple Developer account exists.

---

## 7. Where to read more

| File | Contents |
|---|---|
| [SETUP.md](SETUP.md) | Run it: Xcode, Firebase, rules, two-phone test |
| [Listers-and-Messaging.md](Listers-and-Messaging.md) | Deep dive: data model, rules, chat, applications, meet-ups, reviews, journeys, fostering (§15-18) |
| [Leftover.md](Leftover.md) | What was left out and how to add it |
| [Additions.md](Additions.md) | Extra polish added for a complete feel |
| [SPEC.md](SPEC.md) | The original plan and phases |
| [ARCHITECTURE.md](ARCHITECTURE.md), [CONVENTIONS.md](CONVENTIONS.md), [DESIGN.md](DESIGN.md), [CLAUDE.md](CLAUDE.md) | Code structure, style, colours, notes for the AI assistant |
| [adr/](adr/), [BRANCHING.md](BRANCHING.md) | Decision records and Git habits |
