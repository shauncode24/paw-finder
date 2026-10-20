# PawFinder Architecture

## Layers

```
View -> ViewModel (@Observable, @MainActor) -> Use Case -> Repository (protocol) -> Remote + Core Data
```

- Views: layout and bindings only.
- ViewModels: screen state and user intents; call use cases only.
- Use cases: one verb each (`ToggleFavorite`, `SearchPets`); pure Swift, unit tested.
- Repositories: protocols live in Domain, implementations in Data. The UI observes Core Data; network results are written to it.

## Modules (Swift Packages)

```
PawFinder/            app target: composition root only
Packages/
  DesignSystem  Core  Networking  Persistence  Domain  Data
  Location  ML  Auth  Messaging  TestSupport
  Features/  Discover Swipe PetDetail Favorites Map Identify
             Applications Chat Profile CareHub Onboarding
```

Create packages when the phase that needs them starts.

## Dependency rules

- Core depends on nothing. Domain depends on Core.
- Data depends on Domain, Networking, Persistence.
- Features depend only on Domain, DesignSystem, Core.
- Features never import each other; cross-feature navigation goes through typed `Route`s in the app target.
- Only the app target builds the concrete dependency graph.

## Patterns

- **DI:** `AppEnvironment` holds protocol-typed services, with `.live`, `.mock`, and `.preview` variants.
- **Offline writes:** favorites, collections, applications, and messages go through an outbox with idempotency keys and retry.
- **Navigation:** one `NavigationStack` per tab; a `DeepLinkRouter` turns links, notifications, and intents into routes.
- **Concurrency:** shared mutable state in actors; models are `Sendable` value types.
- **Errors:** one `AppError` with a user-facing message and optional recovery action.
- **Core Data:** unique constraints on remote IDs, `cachedAt` on cached entities, lightweight migrations from day one, separate domain models and managed objects. Plan an App Group store location early for widgets.
