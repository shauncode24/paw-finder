# PawFinder

A SwiftUI pet adoption app: browse adoptable pets, save favorites, find shelters on a map, and identify breeds with Core ML.

Open `PawFinder.xcodeproj` in Xcode and run. Setup steps (signing, API keys, Firebase): [docs/SETUP.md](docs/SETUP.md).

## Folders
```
PawFinder/
  App/            app entry, tab bar, navigation (Router)
  Screens/        screens and their view models (Discover, PetDetail, Favorites, Map, Shelters,
                  Breeds, Applications, Messages, Account, Onboarding, CareHub, Swipe, Settings)
  Models/         app data types (Pet)
  Services/       Petfinder API client, repositories (real + mock)
  DesignSystem/   colors, spacing, fonts, PFButton, PFCard, PFChip, loading/empty/error views
  Config/         Secrets.plist (your keys, gitignored) + Secrets.swift
  Assets.xcassets colors (light + dark) and app icon
docs/             spec, design, setup, Leftover.md (what's not done), Additions.md (extra polish)
```
