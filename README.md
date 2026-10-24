# Daily Hukamnama

The daily Hukamnama from Sri Darbar Sahib, with a morning notification showing its first line.

- The Hukamnama comes live from the [BaniDB API](https://api.banidb.com/v2) by Khalis Foundation and is shown exactly as returned. The app contains no Gurbani text of its own.
- Past Hukamnamas back to 2002, pronunciation, English and Punjabi meanings, adjustable text size, and sharing as text.
- One small family-safe banner ad (Android only).

## How it works

- **App:** Flutter, built entirely in the cloud by GitHub Actions (`.github/workflows/build.yml`) on every push to `main`. Like Gurbani Wallpapers, it publishes a test APK at
  `https://github.com/<owner>/<repo>/releases/download/android-test/daily-hukamnama-test.apk`, a Play Store bundle (**play-store-bundle** artifact), and the web version with the privacy policy on GitHub Pages. An emulator smoke test runs after each build.
- **Notifications:** `.github/workflows/notifier.yml` runs every 15 minutes. `tool/notify_hukamnama.py` checks BaniDB for a new Hukamnama and sends its first line (skipping the heading) through Firebase Cloud Messaging to the `daily-hukamnama` topic, which the app subscribes to. The last date sent is recorded in `notifier/last-sent.txt`, so each Hukamnama is announced once.

## Setup

1. **GitHub Pages:** Settings → Pages → Source: **GitHub Actions**.
2. **Firebase** (free): create a project, add an Android app with package name `com.gurbaniwallpapers.daily_hukamnama`, then in **Settings → Secrets and variables → Actions**:
   - The Firebase client values for project `daily-hukamnama1` are set in `.github/workflows/build.yml` (variables `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_PROJECT_ID` can override them).
   - Secret: `FIREBASE_SERVICE_ACCOUNT` (a service account key JSON from Firebase → Project settings → Service accounts → Generate new private key).
3. **AdMob:** set the app ID in `tool/configure_android.py` and the `ADMOB_BANNER_ID` variable. Until then Google's test ads are used.
4. **Play upload key:** secrets `UPLOAD_KEYSTORE_BASE64` and `UPLOAD_KEYSTORE_PASSWORD` (the same key as Gurbani Wallpapers works).

Without the Firebase settings the app still builds and runs; it just doesn't offer notifications.
