# PawFinder Setup

## 1. Run the app (now)
1. On a Mac, install **Xcode** (16 or newer) from the App Store.
2. Open `PawFinder.xcodeproj`.
3. Click the **PawFinder** target, open the **Signing & Capabilities** tab:
   - **Team:** pick your Apple ID (add it under Xcode › Settings › Accounts if it's missing).
   - **Bundle Identifier:** change `com.example.pawfinder` to something unique, e.g. `com.yourname.pawfinder`.
4. Choose an iPhone simulator and press **⌘R**.

You should see 5 tabs. **Profile › Design system** shows all the colors and components.

## 2. Pet API key (needed for Phase 1)
1. Make an account at https://www.petfinder.com, then go to https://www.petfinder.com/developers/ and request an API key.
2. You get an **API Key** and a **Secret**. Paste them into `PawFinder/Config/Secrets.plist`.

`Secrets.plist` is gitignored. If you clone the repo fresh, copy `Secrets.example.plist` to `PawFinder/Config/Secrets.plist` and fill it in again.

## 3. Firebase (needed for accounts and favorites sync, Phase 7+)
1. Go to https://console.firebase.google.com and click **Add project**. Name it `PawFinder`.
2. Click **Add app › iOS**. Use the **same Bundle Identifier** you set in step 1.
3. Download **GoogleService-Info.plist** and drop it into the `PawFinder/` folder next to `Assets.xcassets`. It's gitignored.
4. Skip the "add SDK" steps for now. We'll add the Firebase package in Xcode when a phase needs it.
5. In the console, turn on:
   - **Authentication** › Sign-in method › **Email/Password** (Apple sign-in later)
   - **Firestore Database** › Create database › start in **test mode** for development

## 4. GitHub
Create an empty repo on GitHub and push. The `.gitignore` already keeps your keys out.
