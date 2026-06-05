# Changelog

All notable changes to **senzu_player** will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.2.0] - 2026-06-03

### Added
- Native Swift Package Manager (SPM) support for iOS plugin.
- Proper Android Audio Focus lifecycle management (`AudioFocusRequest` on API 26+).
- Native background downloader feature supporting DASH/HLS/MP4 (Media3 on Android, AVFoundation on iOS).
- Real-time download size progress (MB size tracking during downloading and completion metrics).
- Real-time download speed calculation and display (`KB/s`, `MB/s`) in progress updates.
- Option to select download quality (e.g. 1080p, 720p, etc.) from HLS master playlist prior to download.
- Localized system download notification alerts, configurable directly from Flutter using `SenzuLanguage`.
- Runtime notification permission request flow on Android 13+ and iOS.
- Updates minimum supported SDK version to Flutter 3.44/Dart 3.27.

### Fixed
- Fixed `SenzuSleepTimerController` ticker/vsync dependency crash by replacing it with a periodic `Timer`.
- Fixed Android thread leak in `SenzuMediaSessionManager` (proper cleanup of artwork executor threads).
- Fixed event stream lifecycle issue in `SenzuCastService` and `SenzuNativeChannel` using listener reference counting.
- Fixed async callback crash in `SenzuTokenManager` by adding a disposed check.
- Fixed `SenzuPlayerBundle` controller disposal order.
- Enabled foreground alert banner notifications on iOS when the app is active.

---

## [1.1.2] - 2025-04-26

### Updated
- Minor fixes and improvements

---

## [1.1.1] - 2025-04-25

### Updated
- Improved README documentation
- Minor fixes and improvements

---

## [1.1.0] - 2025-04-25

### Added
- Android TV & Apple TV support (`isTv: true`)
- Google Cast (Chromecast) support (mobile only)

---

## [1.0.0] - 2025-04-18

### 🎉 Initial Release