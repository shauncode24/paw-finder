# Additions

Finishing touches that weren't in SPEC.md's phase checklists, added to make PawFinder feel like a complete, end-to-end app **from the user's point of view**. None of them add a server, cloud service, test, or new build target; everything runs on the device.

---

## 1. App icon and launch screen
**Why:** an app without an icon looks unfinished the moment you see it on the home screen.

- A new app icon: a white paw on the brand rose gradient, plus a **dark-mode version** (darker background, rose paw). Files: `Assets.xcassets/AppIcon.appiconset/AppIcon.png` and `AppIcon-Dark.png` (1024×1024; Xcode makes the other sizes).
- The **launch screen** now uses the app's background color (light and dark), so there's no white flash when opening the app in dark mode (`UILaunchScreen` in `Info.plist`).

## 2. The Breeds tab (fills the empty Identify tab)
**Why:** Phase 6 (photo breed ID) was skipped, so one of five tabs said "Coming soon". Now it's useful on day one, and photo ID can be added to the same tab later.

- The tab is now called **Breeds**. The code still calls it `.identify`, so deep links like `pawfinder://identify` keep working.
- **"Photo breed ID is coming soon"** card, so users know what's planned.
- **Your best matches:** the top 5 breeds for you, with a **match % ring** and the main reason, worked out from the lifestyle answers. The rules are simple and explainable, in `BreedMatcher`. If the questions aren't answered yet, a card links straight to them.
- **All breeds:** a Dogs/Cats switch and search across all breed guides.
- Every **breed guide** now shows **"Match with your lifestyle"**: the score plus ✓ reasons it fits and ! reasons it might not.
- **4 more breeds** (Chihuahua, Poodle, Greyhound, Ragdoll), for 12 in total, each with structured traits (energy, size, kid-friendly, first-time-friendly, apartment-friendly, OK alone).

Files: `Screens/Breeds/BreedsHubView.swift`, `Screens/Breeds/BreedMatcher.swift`, `Models/CareContent.swift`.

## 3. A friendlier Discover home
**Why:** opening the app should feel personal and give obvious next steps, not just a list.

- **Greeting** that changes with the time of day and uses your first name ("Good evening, Shaun!"). Below it, a status line, e.g. "Your application for Luna is in review."
- **Quick actions:** Swipe, Shelters near me, Breed match, Saved searches, Care Hub.
- **Pet of the day:** a big featured card. The same pet shows all day, and it changes tomorrow.
- Shown only while browsing (no search or filters), so results stay uncluttered.

File: `Screens/Discover/DiscoverHeader.swift`.

## 4. Profile at a glance
- **Stats row:** Favorites · Applications · Shelters followed. Each one is tappable.
- **"Your family 🏡"** section listing pets you've adopted through the app, with the adoption date.
- Shortcut rows to **Care Hub** and **Help & FAQ**.

## 5. Adoption celebration
**Why:** "We brought them home!" is the app's happiest moment, so it should feel like one.

- A full-screen **"Welcome home, Biscuit! 🎉"** with the pet's photo, **falling confetti** (skipped with Reduce Motion), a success vibration, and **Share the news**.
- When you tap Done, the app politely asks for an **App Store review**. iOS limits how often this appears.

Files: `AdoptionCelebrationView` in `Screens/Settings/InfoPages.swift`; triggered from `ApplicationDetailView`.

## 6. Help, legal, and "about" pages
**Why:** real apps have them, and the App Store requires a privacy policy and terms (SPEC §11).

- **Help & FAQ:** 8 expandable answers (how adoption works, whether the pets are real, who replies to messages, accounts, alerts, breed match, using the app without location, deleting data), plus "Email us" and a link to the Care Hub.
- **Privacy Policy:** a plain-language summary matching how the app actually works (on-device data, Firebase Auth for accounts, location only while in use, no tracking or ads, export and delete options).
- **Terms of Use:** a short version.
- **About:** version, mission, and credits (Petfinder attribution, which Petfinder's terms require; sample photo sources; MapKit; Firebase).
- **Send feedback:** opens an email with the app version and iOS version filled in. ⚠️ The address is a placeholder (`support@pawfinder.example` in `SupportInfo`); change it before release.

Find them in **Settings › Help & info**, and Help is also on Profile. File: `Screens/Settings/InfoPages.swift`.

## 7. Settings extras
- **Show the welcome tour again:** replays onboarding. This was on Leftover.md's Phase 7 list.
- **Erase all data on this phone** (with confirmation):
  - **Removes:** favorites (and their saved photos), collections, applications (and attachments), chats, saved searches, followed shelters, recently viewed, Care Hub ticks, your profile and photo, cached results, swipe history, reports, and pending notifications, and it resets the badge.
  - **Keeps:** your account. Handy for demos and for handing a phone to someone else.

## 8. Empty screens that point somewhere
**Why:** an empty screen should always tell you what to do next.

- Favorites → **Browse pets**
- Messages → **Find a pet**
- My applications → **Browse pets**
- Followed shelters → **Find shelters**

---

## Not added (on purpose)
- **Widgets, Live Activities, share/notification extensions:** they need extension targets (see Leftover.md, Phase 14).
- **Photo breed identification:** Phase 6.
- **Anything server- or cloud-based:** for example a real support inbox or remote FAQ content.
