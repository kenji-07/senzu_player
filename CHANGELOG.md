# Changelog

All notable changes to **senzu_player** will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

---
 
## [1.1.0] - 2025-04-23
 
### Added
 
#### Google Cast (Chromecast) support

---

## [1.0.0] - 2026-04-18

### 🎉 Initial Release

#### Core Player
- Native **AVPlayer** (iOS) and **ExoPlayer / Media3** (Android)
- HLS, DASH, and MP4 playback support
- Adaptive Bitrate (ABR) streaming with automatic quality switching
- Configurable buffer thresholds (`minBufferSec`, `maxBufferSec`)
- Looping, seek, playback speed (0.25× – 2.0×)
- Range-limited playback via `Tween<Duration>` (clip start/end)

#### DRM
- **FairPlay** (iOS) via `AVContentKeySession`
- **Widevine** (Android) via `DefaultDrmSessionManager`
- Custom license/certificate URLs with arbitrary headers