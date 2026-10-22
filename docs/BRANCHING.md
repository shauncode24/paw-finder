# Branching

A light version of SPEC §14, for one person (or a small group) working on PawFinder.

- **`main`** always builds. Don't commit half-finished work to it.
- **One branch per feature**, named `feature/<phase>-<short-name>`: `feature/17-meet-greet`, `feature/18-reviews`. Small fixes: `fix/<what>` (for example `fix/chat-scroll`).
- **Commit often, with plain messages** that say what changed: "Add place picker to chat", not "stuff".
- **Merge when it builds and you've tried it**, on a simulator at least. A pull request is worth it even alone: the diff is a good last review.
- **After changing `firestore.rules`**, publish it in the Firebase console before testing on a second device (see SETUP.md). Mention it in the commit message so it isn't forgotten.
- **Never commit** `GoogleService-Info.plist` (it's in `.gitignore`).
- **Update the docs in the same branch**: Leftover.md for what you left out, CLAUDE.md if the structure changed.
