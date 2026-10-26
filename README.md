# MusicApl 🎵

A high-performance, modern cross-platform music streaming and offline player app for **Android** and **iOS**, crafted with **Flutter**, **Riverpod**, **just_audio + audio_service**, **Drift (SQLite)**, and **LRCLIB**.

---

## ✨ Features

1. **Personalized Home & Smart Recommendations**:
   - **Play History Logging**: Logs track ID, artist, tags/genres, played timestamp, and exact completion ratio in a local SQLite database (powered by Drift).
   - **Intelligent Scoring**: Weights plays by recency (7-day and 30-day decay) and completion ratio (>70% listen completion gets a 2x bonus) to rank top artists and genres.
   - **Smart Sections**: *"Because you listened to [Artist]"*, *"More like [Genre]"*, and *"Recently Played"*.
   - **Cold Start Handling**: Automatically presents curated trending music charts when history is empty.
   - **Deduplication**: Excludes recently played tracks from recommendation feeds.

2. **Full-Featured Player & Synced Lyrics**:
   - **2-Tab Layout**: Switch seamlessly between *"Now Playing"* and *"Lyrics"*.
   - **Time-Synchronized Lyrics (LRC)**:
     - Real-time $O(\log N)$ binary search to pinpoint and highlight the current lyric line.
     - Smooth auto-scroll keeping the active lyric line centered in the viewport.
     - Interactive lyrics: tap any line to seek playback directly to that timestamp.
     - Manual timing offset adjustment buttons (`+/- 0.5s`) saved directly to the database.
   - **LRCLIB API Integration**: Primary `/api/get` lookup with automated fallback to `/api/search` and plain-text lyrics fallback.
   - **Lyrics Caching**: All lyrics and user timing offsets are cached in SQLite.

3. **Robust Offline Downloads**:
   - Save high-quality audio files directly to the device documents directory (protects against expiring streaming URLs).
   - Real-time download progress tracking with cancellation and retry capabilities.
   - Background-safe download queue persisting state across app restarts.
   - Dedicated **Library** tab displaying offline songs, file sizes, and one-tap playback from local storage (`AudioSource.file`).

4. **Background Playback & Lock-Screen Integration**:
   - Powered by `just_audio` and `audio_service`.
   - Android foreground media service with notification controls, seek bars, and headset media key handlers.
   - iOS background audio mode (`UIBackgroundModes: audio`) configured with `AVAudioSession`.
   - Automatic streaming URL renewal if YouTube temporary URLs expire.

5. **Design & Navigation**:
   - Dark Theme Material 3 with deep night surface tones and electric violet accents.
   - Persistent mini-player bar above bottom navigation.
   - Declarative routing using `go_router`.

6. **Settings & Diagnostics Log Viewer**:
   - In-app live log inspector capturing audio events, stream resolutions, download queues, and network errors.
   - Real-time search and filtering (Errors only, Warnings, Audio engine, Music source).
   - One-tap **"Copy All Logs"** to clipboard for debugging and reporting issues.
   - Individual log entry tap-to-copy and clear logs functionality.

---

## 🏗 Architecture & Tech Stack

```
lib/
├── main.dart                          # App entry point & AudioService init
├── core/
│   ├── audio/                         # AudioHandler, player engine, Riverpod providers
│   ├── constants/                     # Central configuration constants
│   ├── database/                      # Drift SQLite database, tables, DAOs
│   ├── sources/                       # MusicSource interface & YoutubeMusicSource
│   ├── theme/                         # Material 3 dark theme
│   └── utils/                         # LRC parser, binary search, duration formatting
└── features/
    ├── download/                      # Download manager, Dio pipeline, progress streams
    ├── home/                          # Recommendation engine, personalized sections
    ├── library/                       # Downloaded tracks & history tabs
    ├── lyrics/                        # LRCLIB client, synced lyrics notifier
    ├── navigation/                    # Shell scaffold, GoRouter config, MiniPlayer
    ├── player/                        # Player screen, Now Playing & Lyrics tabs
    └── search/                        # Search screen, trending query tags
```

---

## 🚀 CI/CD & Automated Builds (GitHub Actions)

All builds happen directly in GitHub Actions on every push to `main` or via manual trigger (`workflow_dispatch`):

- **Android (`.github/workflows/android.yml`)**:
  - Environment: `ubuntu-latest`, OpenJDK 17, Flutter stable channel.
  - Generates Drift code and builds release APK: `flutter build apk --release`.
  - Artifact uploaded: `app-release.apk`.
- **iOS (`.github/workflows/ios.yml`)**:
  - Environment: `macos-latest`, Flutter stable channel.
  - Builds unsigned release app: `flutter build ios --release --no-codesign`.
  - Packages into an IPA archive: `app-unsigned.ipa`.
  - Artifact uploaded: `app-unsigned-ipa`.

---

## 📲 How to Install & Sideload

### Installing the Android APK (`app-release.apk`)
1. Download `app-release.apk` from the latest GitHub Actions workflow run under the **Artifacts** section.
2. Transfer or download the APK to your Android device.
3. Open the APK file via your file manager.
4. If prompted, enable **"Install unknown apps"** for your browser or file manager in Android Settings.
5. Tap **Install** and launch **MusicApl**.

---

### Sideloading the iOS IPA (`app-unsigned.ipa`)

Because the IPA produced in GitHub Actions is unsigned, you can sideload it onto any non-jailbroken iPhone or iPad using free sideloading tools like **Sideloadly** or **AltStore**:

#### Option A: Sideloadly (Recommended, macOS & Windows)
1. Download and install [Sideloadly](https://sideloadly.io/).
2. Download `app-unsigned.ipa` from the GitHub Actions artifacts.
3. Connect your iOS device to your computer via USB (or ensure Wi-Fi sync is enabled in Finder/iTunes).
4. Launch Sideloadly and drag `app-unsigned.ipa` into the Sideloadly window.
5. Enter your Apple ID (used strictly for Apple free developer app signing).
6. Click **Start** to install the app onto your iOS device.
7. On your iOS device, go to **Settings > General > VPN & Device Management**, find your Apple ID under *Developer App*, and tap **Trust**.
8. Launch **MusicApl** and enjoy!

#### Option B: AltStore (macOS & Windows)
1. Install [AltServer](https://altstore.io/) on your computer and install AltStore on your iOS device.
2. Download `app-unsigned.ipa` on your iPhone (e.g. using Safari or Files app).
3. Open **AltStore** on your iPhone, go to **My Apps**, and tap the **+** icon in the top left corner.
4. Select `app-unsigned.ipa`.
5. AltStore will sign and install MusicApl directly on your device.

---

## 🛠 Local Development & Testing

Run unit tests:
```bash
flutter test
```

Generate Drift database code:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 📄 License
MIT License. Built for seamless cross-platform music streaming.
