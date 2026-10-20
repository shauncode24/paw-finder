# PawFinder Setup

## 1. Run the app (now)
1. On a Mac, install **Xcode** (16 or newer) from the App Store.
2. Open `PawFinder.xcodeproj`. The first time, Xcode downloads the Firebase package (needs internet; takes a minute or two, see the progress at the top of the window).
3. Click the **PawFinder** target, open the **Signing & Capabilities** tab:
   - **Team:** pick your Apple ID (add it under Xcode › Settings › Accounts if it's missing).
   - **Bundle Identifier:** change `com.example.pawfinder` to something unique, e.g. `com.yourname.pawfinder`.
4. Choose an iPhone simulator and press **⌘R**.

The first launch shows the welcome screens. After that you'll see 5 tabs. **Profile › Design system** shows all the colors and components.

## 2. Pet API key (needed for Phase 1)
1. Make an account at https://www.petfinder.com, then go to https://www.petfinder.com/developers/ and request an API key.
2. You get an **API Key** and a **Secret**. Paste them into `PawFinder/Config/Secrets.plist`.

`Secrets.plist` is gitignored. If you clone the repo fresh, copy `Secrets.example.plist` to `PawFinder/Config/Secrets.plist` and fill it in again.

## 3. Firebase accounts (Phase 7)
Without this, the app still works, but only as a guest (sign-in screens show a "not set up" note).

1. Go to https://console.firebase.google.com and click **Add project**. Name it `PawFinder`.
2. Click **Add app › iOS**. Use the **same Bundle Identifier** you set in step 1.
3. Download **GoogleService-Info.plist** and drop it into the `PawFinder/` folder next to `Assets.xcassets`. It's gitignored. Xcode picks it up automatically.
4. Skip the console's "Add Firebase SDK" and "Add initialization code" steps; they're already done.
5. In the console, open **Build › Authentication › Get started › Sign-in method** and enable **Email/Password**.
   (Usernames also use this: a username like `shaun_k` is stored as `shaun_k@users.pawfinder.app`.)
6. Run the app and create an account from **Profile › Sign in or create account**. It shows up under Authentication › Users in the console.

Later (Phase 8, sync): **Build › Firestore Database › Create database**.

## 4. Sign in with Apple (when you have a paid Apple Developer account)
The button is already in the app. Without a paid account it shows "needs a paid Apple Developer account".

1. In Xcode: PawFinder target › **Signing & Capabilities** › **+ Capability** › **Sign in with Apple**. Make sure your paid team is selected.
2. In the Firebase console: Authentication › Sign-in method › **Apple** › Enable. (For an iOS-only app you don't need the Services ID or private key fields.)
3. Test on a real iPhone or a simulator signed in to an Apple ID.

## 5. GitHub
Create an empty repo on GitHub and push. The `.gitignore` already keeps your keys out (`Secrets.plist`, `GoogleService-Info.plist`).
