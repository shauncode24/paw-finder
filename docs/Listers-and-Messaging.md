# Listers, Listings & Real Messaging

This document covers the change that turned PawFinder from "an app that reads a pet API" into "a two-sided marketplace": **adopters** browse and apply, and **listers** (a person or a rescue) post the pets. It explains **what changed**, **how it works**, **how to set it up**, and **how to extend it**.

- [1. The change in one page](#1-the-change-in-one-page)
- [2. The two personas](#2-the-two-personas)
- [3. Architecture](#3-architecture)
- [4. Data model (Firestore)](#4-data-model-firestore)
- [5. Security rules](#5-security-rules)
- [6. Listings in detail](#6-listings-in-detail)
- [7. Real messaging in detail](#7-real-messaging-in-detail)
- [8. Applications in detail](#8-applications-in-detail)
- [9. Setup, step by step](#9-setup-step-by-step)
- [10. Testing it with two accounts](#10-testing-it-with-two-accounts)
- [11. Free-plan math and limits](#11-free-plan-math-and-limits)
- [12. Files: added, changed, removed](#12-files-added-changed-removed)
- [13. How to extend it](#13-how-to-extend-it)
- [14. Known limitations](#14-known-limitations)

---

## 1. The change in one page

| Before | After |
|---|---|
| Pets came from the **Petfinder API** (needed an API key, US/Canada only, read-only) | Pets are **listings posted by PawFinder users**, shared live through **Firebase Firestore** |
| Placeholder/sample pets filled in when the API wasn't reachable | The listings **are** the data. No placeholder pets at runtime. An empty app says "No pets listed yet" and offers "List a pet" |
| One kind of user: the adopter | Two roles on **the same account**: adopter and **lister** (no separate login) |
| Chat with a **simulated shelter** that sent canned replies from the phone | **Real user-to-user chat** between adopter and lister, live, with "Sent/Read" and "typing…" |
| Applications were answered by a **simulated shelter** | Applications go to the **lister**, who reviews them in an inbox; the adopter sees status changes live |
| `Secrets.plist` with API keys | **Removed.** The only config file is `GoogleService-Info.plist` |
| No cloud except sign-in | Firestore stores listings, profiles, chats, applications, and reports. Still **no server to run** and **no paid plan** |

Nothing is "simulated" any more except a small preview-only sample used by SwiftUI previews (`MockPetRepository`, never used when the app runs).

## 2. The two personas

It's **one account with two hats**, not two logins.

| | Adopter | Lister |
|---|---|---|
| Who | Someone looking for a pet | A person rehoming a pet, or a rescue/shelter |
| Becomes one by | Doing nothing (default) | Profile › **List a pet for adoption** → a one-minute lister profile (first time only) |
| Can | Browse, search, favorite, swipe, compare, apply, message | Everything an adopter can, plus: create/edit/delete listings, mark pets pending/adopted, review applications, chat with applicants |
| Needs sign-in? | Browsing and favoriting: **no**. Messaging, applying, listing: **yes** | Yes |
| Sees under Profile | My applications, Messages | **My listings**, **Applications received**, **Lister profile**, plus the adopter items |

A lister is simply an account whose `users/{uid}` document has `isLister = true`. You can be both at once: list your foster dog while applying for a cat.

## 3. Architecture

```
 Adopter's iPhone                          Firebase (free Spark plan)                 Lister's iPhone
 ┌───────────────────┐                     ┌───────────────────────────┐              ┌───────────────────┐
 │ Discover          │◀── live listener ───│ listings/{id}             │◀── publish ──│ Listing form      │
 │ Pet detail        │                     │ listings/{id}/photos/{n}  │              │ My listings       │
 │ Chat              │◀─ live listener ───▶│ conversations/{id}        │◀─ listener ─▶│ Chat              │
 │ Apply / tracker   │──── submit ────────▶│ conversations/{id}/messages│              │ Applications in   │
 │                   │◀─ status updates ───│ applications/{id}         │◀─ decisions ─│ box               │
 └───────────────────┘                     │ users/{uid}  (lister info) │              └───────────────────┘
        │  Firebase Auth (email / username / Apple)                       │
        └────────────────────────────────────────────────────────────────┘
```

Key ideas:

1. **One live feed for listings.** `ListingsService` opens a single Firestore *snapshot listener* on active listings. Every phone gets the full set once, then only changes. **Searching, filtering, sorting and distance happen on the phone.** This keeps reads low on the free plan and means Firestore needs **no composite indexes**.
2. **The repository pattern stayed.** Screens still talk to `PetRepository`. Only the implementation changed: `FirestoreListingsRepository` replaced the Petfinder one. That's why Discover, Swipe, Compare, saved searches, followed listers and favorites needed few changes.
3. **Photos live inside Firestore.** No Firebase Storage (which now needs a paid plan). Each listing keeps a ~10 KB base64 thumbnail in its document and up to five ~100 KB photos in a `photos` sub-collection. A `pfphoto:` URL scheme lets existing views keep using `URL`s (see [6](#6-listings-in-detail)).
4. **Offline for free.** Firestore keeps a local copy on the phone. Browsing works offline, and writes made offline (like chat messages) are queued and sent when the connection returns.

## 4. Data model (Firestore)

All field names are exact (see `Models/Listing.swift`, `Models/ListerProfile.swift`, `Models/Chat.swift`, `Models/ReceivedApplication.swift`).

### `users/{uid}`: lister profile (public)
`displayName`, `isOrganization`, `organization`, `bio`, `city`, `state`, `postcode`, `latitude`, `longitude` (approximate, from the postcode), `contactEmail`, `contactPhone`, `website`, `adoptionPolicy`, `avatar` (base64 JPEG, ~160 px), `isLister`, `createdAt`, `updatedAt`.
Only listers have this document. No street address is collected.

### `listings/{listingId}`: one pet
| Group | Fields |
|---|---|
| Owner | `ownerID`, `ownerName` |
| Basics | `name`, `species` (Dog/Cat/Rabbit/Bird), `breed`, `secondaryBreed`, `mixed` |
| About | `age` (Baby/Young/Adult/Senior), `ageDetail`, `gender`, `size`, `colors`, `coat`, `weight`, `temperament` (array) |
| Getting along | `goodWithKids`, `goodWithDogs`, `goodWithCats` (**omitted = "not sure"**), `houseTrained` |
| Health | `vaccinated`, `spayedNeutered`, `microchipped`, `specialNeeds`, `specialNeedsNotes`, `healthNotes` |
| Adoption | `adoptionFee` (number, 0 = free), `description`, `videoLink`, `status` (`available`/`pending`/`adopted`), `isActive` (`status != adopted`) |
| Where | `city`, `state`, `postcode`, `latitude`, `longitude` |
| Contact | `contactEmail`, `contactPhone` (optional) |
| Media | `photoCount`, `thumbnail` (base64 JPEG ~280 px) |
| Times | `createdAt` (Timestamp), `updatedAt` (server time) |

`listings/{id}/photos/{0…4}`: `{ data: <base64 JPEG ≤ 900 px>, order: Int }`.

### `conversations/{listingID}_{adopterID}`: one chat per adopter per pet
`listingID`, `listingName`, `listingSpecies`, `adopterID`, `adopterName`, `listerID`, `listerName`, `participants` (array of the two user IDs), `lastMessage`, `lastMessageAt`, `lastSenderID`, `unread` (map uid → count), `lastRead` (map uid → time), `typing` (map uid → time), `blockedBy` (array), `createdAt`.
The ID format means "does a chat already exist?" is a single lookup, with no search.

`conversations/{id}/messages/{messageId}`: `senderID`, `text` (optional), `image` (optional base64 JPEG ≤ 800 px), `createdAt` (server time).

### `applications/{applicationId}` (the ID is the adopter's local UUID)
`adopterID`, `adopterName`, `listerID`, `listingID`, `petName`, `petSpecies`, `status` (`Submitted`, `In review`, `Interview`, `Approved`, `Declined`, `Adopted`, `Withdrawn`), `formJSON` (the whole form as JSON text), `events` (array of JSON text, one per status change), `submittedAt`, `updatedAt`.

### `reports/{id}`
`type` (`listing`/`conversation`), the item's ID, `reason`, optional `details`, optional `reporterID`, `createdAt`. Write-only from the app: read them in the Firebase console.

## 5. Security rules

The rules live in **`firestore.rules`** at the repo root. Publish them in the Firebase console (see [9](#9-setup-step-by-step)). In plain English:

| Collection | Read | Write |
|---|---|---|
| `users` | anyone (listers are public) | only the owner |
| `listings` and `photos` | anyone (so guests can browse) | only the lister who owns it |
| `conversations` | only its two participants | participants only; a chat's two participants can't be changed |
| `messages` | only the two participants | only a participant, as themselves, and **not while the chat is blocked** |
| `applications` | the adopter and the lister it was sent to | the adopter creates it; the **lister** changes its status; the adopter can only withdraw it or mark it adopted |
| `reports` | nobody (console only) | anyone |

Two details worth knowing:
- Photos and messages are written in the **same batch** as their parent (listing / conversation update). Rules then use `getAfter()` (the state *after* the batch) instead of `get()`, otherwise a brand-new listing's photos would be rejected.
- The rule `resource == null || …` on conversations lets the app ask "does this chat exist yet?" before creating it.

These rules are good for a class project and a real demo, but see [14](#14-known-limitations) for what a production app would tighten.

## 6. Listings in detail

**Creating a listing** (`Screens/Lister/ListingFormView.swift`) is one scrolling form:
photos (up to 5, first = cover, long-press to reorder/remove) → basics (name, species, breed with suggestions from `BreedCatalog`, mixed breed) → about them (age group + exact age, gender, size, coat, colors, weight, temperament chips) → getting along (kids/dogs/cats, house-trained) → health (vaccinated, spayed/neutered, microchipped, special needs, notes) → adoption (fee, story, video link) → location & optional contact → (when editing) status.
`ListingDraft.problems` lists what's missing, shown if you tap Publish too early.

**Publishing** (`ListingsService.publish`):
1. Photos are already shrunk to ≤ 900 px when picked (`ImageCompressor`).
2. A 280 px thumbnail is made from the cover photo.
3. The city/postcode is geocoded to an approximate latitude/longitude.
4. One **batch write** saves the listing and its photos together, and removes photos that were deleted while editing.
5. Firestore's latency compensation shows it in your own feed immediately; other phones get it within a second or two.

**Showing listings**
- `ListingsService` keeps `listings` (everything active, newest first) up to date.
- `PetFilters.matches(_:)` (in `Models/Listing.swift`) applies every filter on the phone. Location filtering geocodes what you typed (or uses GPS) and measures distance to each listing's coordinates.
- `DiscoverView` listens to `ListingsService.revision`: when anyone posts or edits, it quietly refreshes in place (`DiscoverViewModel.feedChanged`) without jumping to the top.

**Photos without Storage:** the app stores photos in Firestore, but views just use `URL`s. Listing photos use a private scheme: `pfphoto:///thumb/<id>`, `pfphoto:///photo/<id>/<n>`, `pfphoto:///avatar/<uid>`. `RemoteImage` (like `AsyncImage`) hands those to `PhotoLoader`, which pulls the thumbnail from the live feed, or reads the photo document, and caches it in memory.

**Statuses:** `available` → `pending` (set automatically when you approve an application) → `adopted` (removes it from Discover). Anyone who favorited the pet is notified of changes by the background check (`FavoritesStore.refreshStatuses`).

## 7. Real messaging in detail

You asked for "polling or socket". PawFinder uses a **socket-style live connection** with no polling:

> A Firestore **snapshot listener** keeps one long-lived connection open to Firebase (gRPC/WebChannel under the hood). When a message document is created on one phone, the server pushes it down that connection to the other phone. That is exactly the behaviour of a WebSocket chat, and you write no socket code.

**How a message travels** (`Services/MessagesStore.swift`, `Screens/Messages/*`):
1. Sender taps Send → `MessagesStore.send` writes **one batch**: the message document, plus an update of the conversation (`lastMessage`, `lastMessageAt`, `lastSenderID`, and `unread.<otherUser> += 1`).
2. The write is **not awaited**. Firestore shows it instantly (marked *pending*, "Sending…"), and sends it when it can. Offline, it shows "Waiting to send" and goes out on reconnect (this is the **outbox**, built into Firestore).
3. The recipient's listeners fire: the **conversation list** updates its preview and unread badge, and an **open chat** appends the message.
4. When the recipient has the chat open, `markRead` sets `unread.<me> = 0` and `lastRead.<me> = now`. The sender compares that to each message's time and shows **Read**.
5. **Typing:** while the text field changes, the app writes `typing.<me> = now` (at most every ~2.5 s; cleared after a 4 s pause or on send). The other phone shows "… is typing" if that time is under 8 s old.
6. **Photos:** shrunk to ≤ 800 px and stored in the message document (`image`).

**Safety:** `ContentModerator` (unchanged) blocks a few abusive words and warns about payment/scam phrases before sending. Anyone can **report** a chat or a single message (saved in `reports`) and **block** a chat (`blockedBy`; the rules then refuse new messages from either side until unblocked).

**Notifications for chat** (no server, so no remote push):
- App open, chat not on screen: a local notification appears the moment the listener sees the new message.
- App closed: iOS runs `BackgroundRefresh` now and then; `MessagesStore.backgroundCheck()` fetches your chats once and notifies about anything new. Timing is up to iOS (typically minutes to hours).
- Instant delivery to a closed app needs **push notifications**, which need a small server (a Firebase Cloud Function) and a paid Apple Developer account. See [13](#13-how-to-extend-it).

**If you ever want real polling or your own WebSocket server instead:** the screens only call `MessagesStore` (`send`, `markRead`, `setTyping`, `openConversation`, …). Replace its internals with REST polling (`GET /conversations/{id}/messages?after=<time>` every few seconds) or a `URLSessionWebSocketTask`, and keep the same published properties (`conversations`, `unreadCount`) and `ChatViewModel.messages`. No view needs to change.

## 8. Applications in detail

- The adopter fills in the multi-step form on their phone (drafts autosave locally). Attached photos (ID, lease, …) **stay on the adopter's phone**; they're not uploaded.
- **Submit** writes `applications/{id}` (waits for the server, so a failure is reported: "You're offline", etc.). One application per adopter per pet.
- The **lister** sees it under Profile › **Applications received** (a live list, with a notification and a tab badge for new ones) and can: *Start reviewing* → *Invite for a chat or meeting* → *Approve* / *Decline* → *Mark as adopted*, adding an optional note each time. **Approve** sets the listing to *pending*; **Mark as adopted** sets it to *adopted*.
- The **adopter's** copy updates live (status, timeline, the lister's notes), with a notification per decision and the "Bring them home" checklist after approval.
- Either side can **message** the other from the application screens.

## 9. Setup, step by step

Full instructions are in [SETUP.md](SETUP.md). The short version:

1. **Firebase project + iOS app + `GoogleService-Info.plist`** into `PawFinder/` (the bundle ID must match Xcode's).
2. **Authentication › Sign-in method › Email/Password → Enable.**
3. **Firestore Database › Create database** (Standard edition, any region, *production mode*).
4. **Rules tab → paste all of `firestore.rules` → Publish.**
5. Run the app. If Discover says "Not connected yet", the plist is missing or not in the app target. If it says it can't read listings, the rules weren't published.

No API keys, no server, no billing.

## 10. Testing it with two accounts

You need two sign-ins. Two simulators work; a phone plus a simulator is best.

| Step | Device A (lister) | Device B (adopter) |
|---|---|---|
| 1 | Sign up. Profile › **List a pet for adoption** → fill the lister profile → **Continue** | Sign up with another email |
| 2 | Add photos, details, **Publish** | Discover: the pet appears within seconds (try pulling to refresh if not) |
| 3 | | Open the pet › **Message Sam** (the lister's name). Send "Hello!" |
| 4 | Profile › **Messages**: unread badge. Open it; reply | Watch **Read** appear, then "typing…" while A types |
| 5 | | **Apply to adopt**, submit |
| 6 | Profile › **Applications received** (a "new" badge). **Start reviewing** → **Approve** | My applications: status and notes update live; the pet shows "Adoption pending" |
| 7 | **Mark as adopted** | The pet leaves Discover; B can tap "We brought … home!" |
| 8 | Turn on airplane mode, send a message | It shows "Waiting to send"; turn airplane mode off and it delivers |

## 11. Free-plan math and limits

Firestore Spark plan (verify at https://firebase.google.com/pricing): 1 GiB stored, 50,000 reads and 20,000 writes per day.

- **Browsing:** the live feed downloads each active listing **once** (thumbnail included, ~10–15 KB) and then only changes. 500 listings ≈ 5–8 MB on first launch, then nearly free. Full-size photos are read only when you open a pet (≈ 5 reads).
- **Chat:** one message ≈ 2 writes + a few reads. A busy demo day stays far below the limits.
- **Storage:** a listing with 5 photos ≈ 0.5–0.7 MB. 1 GiB ≈ 1,500+ listings.
- **Caps in the app:** 5 photos per listing; the feed loads the newest **500** active listings (`ListingsService.startFeed`); 40 messages per chat page ("Load earlier messages").
- If you hit a quota, Firebase pauses access until the daily reset. The app shows "Too many requests".

## 12. Files: added, changed, removed

**Removed** (the Petfinder API and everything around it): `PetfinderClient`, `PetfinderModels`, `FallbackPetRepository`, `PetCache`, `Secrets.swift`, `Secrets.plist`, `Secrets.example.plist`, `PetVideoView`, the old local `Conversation` model, the simulated shelter replies (in `MessagesStore` and `ApplicationsStore`).

**Added**
- Data: `Models/Listing.swift` (draft, status, mapper, filter matching), `Models/ListerProfile.swift`, `Models/BreedCatalog.swift`, `Models/Chat.swift`, `Models/ReceivedApplication.swift`.
- Services: `ListingsService`, `FirestoreListingsRepository` (inside `PetRepository.swift`), `ListerProfileStore` (+ `ListerDirectory`), `PhotoLoader` (+ `RemoteImage`, `ImageCompressor`), `MessagesStore` (rewritten), `MessagesStore+Opening`.
- Screens: `Screens/Lister/` (`ListerSetupView`, `ListingFormView`, `MyListingsView`, `ReceivedApplicationsView`), `Screens/Messages/ChatViewModel`.
- Config: `firestore.rules`.

**Rewritten:** `ChatView`, `ConversationsListView`, `ApplicationsStore`, `NotificationManager` (message/application notifications), `ShelterGeocoder`, `MockPetRepository` (now preview-only).

**Changed:** `Pet` (new optional fields), `Shelter` (now a lister's public profile), `PetFilters` (Petfinder request code removed), `PetDetailView` (fee/health/"Listed by", real message button, owner controls), `DiscoverView/ViewModel` (live refresh, empty state), `ProfileView` (lister section), `RootView` (sign-in sheet), `Router` (new routes), `PawFinderApp`, settings/help/privacy text, and the Xcode project (adds the `FirebaseFirestore` package product).

## 13. How to extend it

| Goal | How |
|---|---|
| **Add a field to listings** (e.g. "energy level") | 1) add it to `ListingDraft`; 2) read/write it in `ListingMapper.draft/data/pet`; 3) add a `Pet` property (optional, with a default); 4) add a control in `ListingFormView`; 5) show it in `PetDetailView`; 6) (optional) filter on it in `PetFilters` + `PetFilters.matches`. No Firestore change is needed |
| **Instant push for chat/applications** | Needs a paid Apple Developer account (APNs key) and Firebase **Cloud Functions** (Blaze plan). Add an `onCreate` function for `conversations/{id}/messages/{id}` that sends an FCM push to the other participant, and the same for `applications`. Store each device's FCM token in `users/{uid}`. The app side: add the `FirebaseMessaging` package and call `registerForRemoteNotifications` |
| **Move photos to Firebase Storage** (smaller documents, faster) | Needs the Blaze plan. Upload JPEGs to `listings/{id}/{n}.jpg`, store the download URLs in the listing, and make `PhotoURL` return those `https` URLs. `RemoteImage` already handles normal URLs |
| **Faster "near me" for thousands of listings** | Add a geohash field to listings and query by prefix (the `GeoFire`-style approach), then keep client-side filtering for the rest |
| **A moderator tool** | Read `reports` in the console, or build a small admin view guarded by a custom claim (`request.auth.token.admin == true`) and add rules to read `reports` and delete any listing |
| **Verified rescues** | Add `isVerified` to `users/{uid}`, set it from the console, show a badge in `ShelterCard`, and add a "Verified only" filter |
| **Sync favorites across devices** | Add a `users/{uid}/favorites` sub-collection and mirror `FavoritesStore` into it (this is the "Phase 8" work from `SPEC.md`) |
| **Your own server instead of Firebase** | Keep the same protocols: implement `PetRepository` over REST and replace `MessagesStore`'s internals with a WebSocket client. The screens don't change |

## 14. Known limitations

- **Rules are "good enough", not hardened.** Either chat participant can edit any field of the chat document (meet-up message edits are limited to `meetup.status`), and `reports` can be written by anyone. Listings are public to everyone, including guests.
- **No push when the app is closed** (see [7](#7-real-messaging-in-detail)); chat notifications depend on iOS's background refresh.
- **Application attachments aren't uploaded** (privacy); listers can ask for documents in chat.
- **Applications are matched to the adopter's phone by ID.** A new phone won't show old applications' drafts (the lister still has them).
- **Free-plan size limits:** 5 photos per listing; the feed loads the newest 500 active listings.
- **Distances are in miles** and locations are geocoded with Apple's service (rate-limited; results are cached).
- **Listing `ownerName` is saved when you publish.** If a lister renames themselves, old listings keep the old name until edited (the lister profile page shows the new one).
- **Deleting an account** removes the user's listings and public profile, but leaves chats and applications so the other person's history isn't broken.
- **Not yet built or tested:** the project hasn't been compiled in Xcode since these changes were written. Expect a short round of compile fixes.

---

## 15. Meet & Greet planner (Phase 17, MapKit)

The map is no longer decoration. A lister and an adopter can agree on a place and time to meet a pet, entirely inside the chat, and the app helps both of them get there.

### What the user sees
| Where | What |
|---|---|
| **Chat composer** | A 📍 button next to the photo button: **Suggest a meet-up**. |
| **Place picker** | Search box with suggestions as you type, shortcut chips (Dog parks, Cafés, Vets, Pet stores), a pin in the middle of the map (move the map to move the pin, the address follows), a date and time, and **Send proposal**. |
| **Chat card** | The proposal appears as a card with a mini map, place, address and time. The other person taps **Accept**, **Decline** or **Suggest another place or time** (which marks the old card "Changed" and sends a new one). Either person can **Cancel** an accepted one. |
| **Route screen** (tap the card) | Map with the route line, **Drive / Walk / Transit** switch, travel time, distance, "Leave by 3:40 PM to arrive on time", a **Look Around** street-view preview (hidden where Apple has no imagery) and **Open in Apple Maps** for turn-by-turn. |
| **Reminder** | One local notification an hour before an accepted meet-up, on both phones. |
| **Messages screen** | An **Upcoming meet-ups** section on top. |
| **Map tab › Pets** | One round photo pin per pet (not per lister), pins merge into numbered bubbles when zoomed out, a **distance circle** that matches the distance chip, species chips, and a card that opens the pet. Several pets at one address open a list instead of zooming forever. **Listers** is the old lister map. |
| **Care Hub** and **Welcome home** | **Near you**: vets, pet stores, dog parks and groomers from Apple Maps, with call and directions. |

### How it is built
- **No new Firestore collections.** A proposal is a normal chat message with a `meetup` map instead of `text`: `placeName, address, latitude, longitude, date, status, proposedBy`. `status` is `proposed`, `accepted`, `declined` or `changed`.
- **Accepting** updates the message's `meetup.status` and sets `nextMeetupAt` / `nextMeetupPlace` on the conversation document in one batch. Because each phone already listens to its conversations, both phones see the meet-up, show it in **Upcoming meet-ups**, and schedule the reminder (`MessagesStore.updateMeetupReminders`), even if the chat isn't open. Cancelling removes both fields and the reminder.
- **MapKit pieces used:** `Map` with `Marker`/`Annotation`/`MapPolyline`/`MapCircle`, `MKLocalSearchCompleter` (suggestions), `MKLocalSearch` (shortcuts and nearby places), `CLGeocoder` (naming the pin), `MKDirections` (route and `calculateETA` for transit), `LookAroundPreview`, `MKMapItem.openInMaps`.
- **Security rule added** (re-publish `firestore.rules`!): a participant may edit an existing meet-up message, but only its `meetup.status`. Text, sender and times can't be changed.

### Files
| New | Purpose |
|---|---|
| `Models/Meetup.swift` | `Meetup`, `MeetupStatus` |
| `Services/PlaceSearch.swift` | `FoundPlace`, `PlaceSearch` (search, describe a pin, fit a region), `PlaceSearchCompleter` |
| `Screens/Map/PlacePickerView.swift` | the picker |
| `Screens/Map/MeetupMapView.swift` | route, ETA, Look Around |
| `Screens/Map/PetsMapView.swift` | `MapHomeView` (Pets / Listers switch), `PetsMapView`, `PetCluster` |
| `Screens/Map/NearbyPlacesView.swift` | vets, pet stores, parks, groomers |
| `Screens/Messages/MeetupCard.swift` | the chat card |

| Changed | What |
|---|---|
| `Models/Chat.swift` | `ChatMessage.meetup`, `Conversation.nextMeetupAt/Place` |
| `Services/MessagesStore.swift` | `proposeMeetup`, `respondToMeetup`, `upcomingMeetups`, reminders |
| `Services/NotificationManager.swift` | `scheduleMeetupReminder`, `cancelMeetupReminder` (uses the "Messages" switch) |
| `Screens/Messages/ChatView.swift`, `ConversationsListView.swift` | 📍 button, card, picker sheet, upcoming section |
| `App/Router.swift`, `Screens/PlaceholderScreens.swift` | routes `.meetupMap(Meetup)`, `.nearbyPlaces`; Map tab uses `MapHomeView` |
| `Screens/CareHub/CareHubView.swift`, `Screens/Settings/InfoPages.swift` | "Near you" entry points |
| `firestore.rules` | meet-up message update rule |

### To try it
1. Make sure the new `firestore.rules` is published (Firestore › Rules).
2. Use two accounts as in section 10. On the adopter's phone open the chat, tap 📍, pick a park, choose a time, send.
3. On the lister's phone accept it. Both phones now show it under **Messages › Upcoming meet-ups**; tap the card for the route. In the simulator set a location (Features › Location) or the route will say it needs location.
4. Map tab › **Pets**: your listing appears as a photo pin if its location was found when it was published.

### Limits
- Needs location permission for routes and "Near you"; without it the spot is still shown.
- Transit routes are an estimate only; Apple draws transit lines in the Maps app.
- Look Around, routes and place search depend on Apple's coverage and aren't available everywhere.
- Reminders need the notification permission and respect quiet hours (skipped if quiet hours would push it past the meet-up).
- Pets show on the pet map only if the listing has coordinates (taken from the lister's profile or the listing's city/postcode when published).
- Dates use the phone's time zone; two people in different zones see the same moment in their own time.

---

## 16. Lister reviews (Phase 18)

After an adoption is complete, the adopter can rate the lister from 1 to 5 stars and leave a short note. The average shows wherever the lister is shown, so the next adopter can trust (or avoid) them.

### What the user sees
| Where | What |
|---|---|
| **Welcome home screen** | After "We brought Luna home!", a **Rate <lister>** button (the review sheet opens once the celebration closes). |
| **Application detail** (status Adopted) | A **Rate <lister>** button. If you already reviewed, it opens your review so you can change it. |
| **Review sheet** | Five tappable stars, an optional note (500 characters), and a reminder that the first name and last initial are public. Reviews can be edited for 7 days, then they're final. |
| **Pet page, lister card** | Stars and "4.8 (12 reviews)", or "No reviews yet". Tap to read them. |
| **Lister profile** | The same line under the name. |
| **Reviews screen** | Big average, then reviews newest first. The ••• menu on each review has **Report review** (Not a real adoption, Rude or abusive, Spam, Something else). Anyone can report, including the lister being reviewed. |

### How it is built
- **`reviews/{applicationID}`** holds one review per adoption (the document ID is the application's ID): `listerID, reviewerID, reviewerName, petName, rating, text, createdAt, updatedAt`.
- **The lister's average** is kept on their `users/{uid}` document as `ratingSum` and `ratingCount`, updated in the **same batch** as the review with `FieldValue.increment`. Pet pages and profiles read that one document instead of every review, which keeps the free plan's read count low. `ListerProfile.rating` / `Shelter.rating` carry it to the screens.
- **A review list** is a plain query on `listerID` (newest 100), sorted on the phone, so it needs no index.
- **Reports** go to the existing `reports` collection with `type: "review"`.
- **Security rules** (re-publish `firestore.rules`):
  - A review can be created only by the adopter of that application, only when its status is `Adopted`, and only with 1-5 stars.
  - It can be edited (stars, text) by its author for 7 days, and never deleted. The lister cannot touch it.
  - `ratingSum`, `ratingCount` and `lastReviewID` on a user can **not** be set by the user themselves. They can only change together with a matching review in the same batch: a new review adds 1 to the count and its stars to the sum; an edit changes the sum by the difference.
- A lister reviewing their own pet is blocked in the app and by the rules (the reviewer must be the application's adopter).

### Files
| New | Purpose |
|---|---|
| `Models/Review.swift` | `Review`, `RatingSummary` |
| `Services/ReviewsService.swift` | load reviews, post/edit (one batch), report |
| `Screens/Reviews/ReviewViews.swift` | `StarRatingView`, `RatingSummaryView`, `RatingLink`, `ReviewComposerSheet`, `ListerReviewsView` |

| Changed | What |
|---|---|
| `Models/ListerProfile.swift`, `Models/Shelter.swift` | rating totals |
| `Screens/Applications/ApplicationDetailView.swift` | Rate button and sheet; opens after the celebration |
| `Screens/Settings/InfoPages.swift` | `AdoptionCelebrationView` gets an optional Rate button |
| `Screens/PetDetail/ShelterCard.swift`, `Screens/Shelters/ShelterProfileView.swift` | rating line |
| `App/Router.swift`, `Screens/PlaceholderScreens.swift` | route `.listerReviews(id:name:)` |
| `firestore.rules` | `reviews` rules, protected rating fields |

### To try it
1. Re-publish `firestore.rules`.
2. With two accounts: A lists a pet; B applies; A approves; on B tap **We brought <pet> home!** then **Rate**.
3. On A's profile (or the pet's page) the rating appears. Edit the review on B within a week to see the average change.

### Limits
- Only the adopter can mark an adoption complete, so a lister and a friend could create fake adoptions to post reviews. For a class project that's fine; a real app would need the lister to confirm the adoption (see Phase 19).
- Reviews stay after an account is deleted (the lister's total isn't reduced when a reviewer deletes their account).
- Listers cannot reply to reviews, and reviews have no photos.
- The reviews screen reads at most the newest 100.

---

## 17. Adoption journey (Phase 19)

What happens after "adopted". The adopter gets a page for their new pet with timed check-ins and a place to share photos; the lister sees how the pet is doing and can feature the best updates on their profile as **Happy tails**.

### What the user sees
| Where | What |
|---|---|
| **Profile › Your family** | Each adopted pet, with progress such as "Week 1 · 2 of 4 check-ins done". Tap to open its journey. |
| **My applications** | Adopted rows show the same progress line. |
| **Application detail** (Adopted) | **Open <pet>'s journey** button. |
| **Journey screen (adopter)** | Pet header ("Day 12"), the sharing switch, four check-in cards (Day 1, Week 1, Month 1, Month 3) and the updates feed with a **Share an update** button. |
| **Check-in cards** | Locked until their date ("Opens 14 Dec"). Once open they list 3-4 short tasks to tick, many with a book button that opens the matching Care Hub guide. |
| **Share an update** | A photo and/or up to 500 characters. Posted updates can be deleted from their context menu. |
| **Reminders** | A local notification at 10:00 on the Week 1, Month 1 and Month 3 dates ("Luna: Week 1 check-in"). Controlled by the new "Adoption journey check-ins" switch in notification settings. |
| **Journey screen (lister)** | Opened from **Applications received** once the status is Adopted. Shows the updates feed only; each update has **Show on your profile as a Happy tail** (or remove). |
| **Lister profile** | A **Happy tails** strip with the featured photos and notes: "Luna found a home". Only the pet's name is shown, never the adopter's. Guests don't see it. |
| **Sharing switch (adopter)** | "Let the lister feature my updates." Turning it off immediately takes down everything already featured. |

### How it is built
- **`journeys/{applicationID}`**: `adopterID, listerID, listingID, petName, petSpecies, adoptedAt, shareHappyTails, createdAt`. It is created by the **adopter's phone** the moment the application becomes Adopted, whether the adopter or the lister marked it (`ApplicationsStore.startJourney`), and again on opening the journey if it's missing.
- **`journeys/{id}/updates/{updateID}`**: `authorID, text, photo (base64), createdAt`. The photo is compressed like a chat photo (about 800px). The list is read live; it only starts listening once the journey exists, because the rules look the journey up.
- **`happyTails/{updateID}`**: a copy the lister makes of one update (text, a smaller 500px photo, pet name, `listerID`, `adopterID`, `applicationID`). It is a top-level collection so a profile page can read a lister's tails with one simple query (a query across all journeys would need a special index). The same ID as the update lets both sides know what is featured.
- **Check-in ticks** are kept on the phone only (`JourneyProgressStore`, UserDefaults).
- **Security rules** (re-publish `firestore.rules`):
  - A journey can be created only by the application's adopter, only when the application is `Adopted`, and only afterwards changed by the adopter's sharing switch.
  - Only the adopter and the lister can read a journey and its updates; only the adopter writes updates.
  - A lister can create a Happy tail only for their own journey, only while the adopter's switch is on; the lister or the adopter can delete it. Signed-in people can read Happy tails.

### Files
| New | Purpose |
|---|---|
| `Models/Journey.swift` | `Journey`, `JourneyUpdate`, `HappyTail`, `JourneyMilestone` (dates and tasks), `JourneyTask` |
| `Services/JourneyService.swift` | create journey, post/delete updates, sharing, feature/unfeature, Happy tails query; `JourneyProgressStore` |
| `Screens/Journey/JourneyView.swift` | `JourneyViewModel`, `JourneyView`, check-in cards, update cards, `JourneyUpdateComposer`, `HappyTailsSection`, `Base64Photo` |

| Changed | What |
|---|---|
| `Services/ApplicationsStore.swift` | starts the journey and reminders when an adoption completes (either side) |
| `Services/NotificationManager.swift`, `Models/SavedSearch.swift`, `Screens/Notifications/NotificationPrimingView.swift` | new "journey" category and `scheduleJourneyReminders` |
| `App/Router.swift`, `Screens/PlaceholderScreens.swift` | route `.journey(applicationID:)`, link `pawfinder://journey/<id>` |
| `Screens/Account/ProfileView.swift`, `Applications/ApplicationsListView.swift`, `Applications/ApplicationDetailView.swift`, `Lister/ReceivedApplicationsView.swift`, `Shelters/ShelterProfileView.swift` | entry points, progress, Happy tails strip |
| `Screens/Settings/InfoPages.swift` | FAQ entry, privacy text |
| `firestore.rules` | `journeys`, `updates`, `happyTails` |

### To try it
1. Re-publish `firestore.rules`.
2. With two accounts: A lists a pet, B applies, A approves, then either B taps **We brought <pet> home!** or A taps **Mark as adopted**.
3. On B, Profile › Your family › the pet. Post an update with a photo.
4. On A, Applications received › that application › **See <pet>'s journey**. Tap **Show on your profile as a Happy tail**, then open A's lister profile (Profile › Lister profile, or the lister page from a pet) as B or any signed-in user to see the strip.
5. On B, switch off sharing and watch the Happy tail disappear.
6. To see check-ins unlock without waiting, you can temporarily change `offsetDays` in `JourneyMilestone` to 0.

### Limits
- The lister isn't notified of new updates unless the app happens to be open (no push without a server); they see them when they open the journey.
- Reminders are scheduled on the adopter's phone when the journey is created or opened. If they never open the app after the adoption, none are set.
- The journey doesn't track weight, vet records, or videos.
- If the adopter deletes their account, their journey and any featured Happy tails stay (the adopter can switch sharing off first).
- Happy tails are only visible to signed-in people (guests see no strip).
- Photos live inside Firestore documents, so a very active journey uses storage on the free plan (about 100 KB per update).
