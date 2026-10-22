# PawFinder Setup

PawFinder has no pet API any more. Pets are listed by the app's own users, and
everything is shared through **Firebase** (Authentication + Firestore) on the
**free Spark plan**. You never need a credit card.

You need three things, all in the same Firebase project:
**① the config file → ② Email/Password sign-in → ③ a Firestore database with the rules.**
Skipping ③ means the app can sign people in but can't show or post listings.

## 1. Run the app
1. On a Mac, install **Xcode** (16 or newer) from the App Store.
2. Open `PawFinder.xcodeproj`. The first time, Xcode downloads the Firebase package (needs internet; takes a few minutes now that Firestore is included: watch the progress at the top of the window).
3. Click the **PawFinder** target, open **Signing & Capabilities**:
   - **Team:** pick your Apple ID (add it under Xcode › Settings › Accounts if it's missing).
   - **Bundle Identifier:** change `com.example.pawfinder` to something unique, e.g. `com.yourname.pawfinder`.
4. Choose an iPhone simulator and press **⌘R**.

Until Firebase is set up, Discover shows "Not connected yet". That's expected.

## 2. Firebase project, accounts, and the config file
1. Go to https://console.firebase.google.com and click **Add project**. Name it `PawFinder`. (Analytics isn't needed.)
2. Click **Add app › iOS**. Use the **same Bundle Identifier** as in Xcode.
3. Download **GoogleService-Info.plist** and drop it into the `PawFinder/` folder next to `Assets.xcassets`. It's gitignored. Xcode picks it up automatically.
4. Skip the console's "Add Firebase SDK" and "Add initialization code" steps; they're already done.
5. **Build › Authentication › Get started › Sign-in method** → enable **Email/Password**.
   (Usernames also use this: a username like `shaun_k` is stored as `shaun_k@users.pawfinder.app`.)

## 3. Firestore: the database for listings, chats, and applications
1. **Build › Firestore Database › Create database.**
   - Edition: **Standard**. Location: pick the region closest to you (**it can't be changed later**).
   - Start in **production mode** (the rules below replace the default "deny everything").
2. Open the **Rules** tab, delete what's there, paste in **all of [`firestore.rules`](../firestore.rules)** from the repo root, and click **Publish**.
3. That's it. There are **no indexes to create**; the app only uses simple queries.
4. Run the app, sign in, and try **Profile › List a pet for adoption**.

**Whenever `firestore.rules` changes** (it did for the Meet & Greet planner), paste the whole file into the Rules tab again and click **Publish**. Without the new rule, accepting or declining a meet-up fails quietly.

Why the rules matter: they decide who can read and write what. Without them, either nothing works (default rules) or everything is open to anyone (test mode). What each rule does is explained in [Listers-and-Messaging.md](Listers-and-Messaging.md).

### Free plan limits (Spark)
| | Free per day / total | In practice |
|---|---|---|
| Document reads | 50,000 / day | Listings load once and then stay live, so browsing is cheap |
| Document writes | 20,000 / day | A chat message is about 2 writes |
| Stored data | 1 GiB | Each listing ≈ 0.5–1 MB with photos, so ~1,000 listings |

If a quota is used up, Firebase pauses reads/writes until the next day and the app shows a "too many requests" message. Check usage under **Firestore › Usage**. These numbers are from Firebase's pricing page; verify them at https://firebase.google.com/pricing.

## 4. Try it with two phones (or a phone + the simulator)
1. **Device A:** create an account (Profile), tap **List a pet for adoption**, set up the lister profile, and publish a pet.
2. **Device B:** create a different account. The pet appears in **Discover** within a couple of seconds.
3. On B, open the pet and tap **Message**. On A, open **Profile › Messages**. Type back and forth: you'll see "typing…" and "Read" appear.
4. On B, tap **Apply to adopt**, fill in the form and submit. On A, open **Profile › Applications received** and move it along. B sees each change in **My applications**.

## 5. Sign in with Apple (when you have a paid Apple Developer account)
The button is already in the app. Without a paid account it shows "needs a paid Apple Developer account".

1. In Xcode: PawFinder target › **Signing & Capabilities** › **+ Capability** › **Sign in with Apple**. Make sure your paid team is selected.
2. In the Firebase console: Authentication › Sign-in method › **Apple** › Enable. (For an iOS-only app you don't need the Services ID or private key fields.)
3. Test on a real iPhone or a simulator signed in to an Apple ID.

## 6. GitHub
Create an empty repo on GitHub and push. The `.gitignore` already keeps your `GoogleService-Info.plist` out.
