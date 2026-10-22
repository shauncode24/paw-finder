# 0001: Firebase on the free Spark plan, and nothing else

**Status:** accepted

## Context
The app needs shared data (listings, chats, applications) between real people. The project has no budget, no server to run, and no paid Apple account. Firebase's free Spark plan includes Authentication and Firestore, but Cloud Functions and (now) Cloud Storage need the paid Blaze plan.

## Decision
Use **Firebase Authentication and Firestore only**, on the Spark plan. No Cloud Functions, no Storage, no custom server.

## Consequences
- Real-time features use Firestore snapshot listeners (the "socket"): chat, live listings, application status.
- No push notifications to a closed app. Notifications are local and arrive when the app is open or when iOS runs a background refresh.
- Anything that would need server code (counting, cleaning up after deleted accounts, moderation) is done on the phone, protected by security rules, or left out. See Leftover.md.
- Free-plan quotas (50,000 reads and 20,000 writes a day, 1 GiB) shape other decisions (ADR 0002 and 0003).
