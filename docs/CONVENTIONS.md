# PawFinder Conventions

## Code
- Swift API Design Guidelines; SwiftLint and SwiftFormat are authoritative.
- async/await only; `@Observable` view models, no `ObservableObject` unless an API forces it.
- No force-unwraps, `try!`, or `fatalError` in shipping code. Zero warnings, strict concurrency clean.
- Default to `internal`; make things `public` only when a package needs to expose them.
- All user-facing strings in String Catalogs.
- Use design tokens and `PF*` components; no raw colors or magic spacing.

## UI
- Every screen: loading, empty, error, loaded.
- Dark mode, Dynamic Type (including accessibility sizes), Reduce Motion, accessibility labels.
- iOS 18/26 APIs only behind `#available` with a working fallback.

## Testing
- Unit tests for use cases and mappers; view model state tests with mock repositories; URLProtocol stubs plus in-memory Core Data for repositories.
- XCUITest for critical flows: onboarding, browse to favorite, filter, identify, apply.
- No network in tests. Write tests with the code. A bug fix starts with a failing test.

## Definition of Done
Builds with zero warnings, tests pass, accessibility checked, analytics event added where relevant, and verified on a physical device for camera, ML, location, push, and widget work.

## Privacy and security
- Tokens in Keychain only. No PII in analytics or logs.
- ML inference on-device only; photos are never uploaded for classification.
