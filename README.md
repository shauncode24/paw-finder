# PawFinder

A SwiftUI pet adoption app with two roles on one account: **adopters** browse, chat, and apply; **listers** (people or rescues) post pets for adoption. Listings, chats, and applications are shared live through Firebase.

Open `PawFinder.xcodeproj` in Xcode and run. Setup (signing, Firebase, Firestore rules): [docs/SETUP.md](docs/SETUP.md). How listers, listings and real messaging work: [docs/Listers-and-Messaging.md](docs/Listers-and-Messaging.md).

## Folders
```
PawFinder/
  App/            app entry, tab bar, navigation (Router)
  Screens/        screens and their view models (Discover, PetDetail, Favorites, Map, Shelters,
                  Breeds, Applications, Messages, Account, Onboarding, CareHub, Swipe, Settings)
  Models/         app data types (Pet, Listing, ListerProfile, Chat, ...)
  Services/       Firestore services (listings, chat, applications), photo loading, notifications
  DesignSystem/   colors, spacing, fonts, PFButton, PFCard, PFChip, loading/empty/error views
  Assets.xcassets colors (light + dark) and app icon
firestore.rules   Firestore security rules (publish in the Firebase console)
docs/             spec, design, setup, Leftover.md (what's not done), Additions.md (extra polish)
```
