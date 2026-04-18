# senzu_player

[![pub version](https://img.shields.io/pub/v/senzu_player.svg)](https://pub.dev/packages/senzu_player)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey.svg)]()

A feature-rich Flutter video player backed by **AVPlayer (iOS)** and **ExoPlayer / Media3 (Android)**.  
Designed for streaming apps — supports HLS, DASH, DRM, live streams, ads, subtitles, chapters, PiP, and more.

---

## Features

| Category | Details |
|---|---|
| **Formats** | HLS, DASH, MP4 |
| **DRM** | FairPlay (iOS), Widevine (Android) |
| **Subtitles** | VTT, SRT, encrypted (AES-128), HLS auto-detect |
| **Ads** | Custom inline ads, IMA SDK (VAST/VMAP) |
| **Live** | DVR, low-latency, auto-reconnect |
| **Feed** | TikTok-style `PageView`, Instagram-style `ListView` |
| **PiP** | iOS 14+ / Android 8+ |
| **Lock screen** | Now Playing controls on iOS & Android |
| **Chapters** | OP/ED skip buttons, progress bar markers |
| **Annotations** | Timed overlay widgets |
| **Watermark** | Animated user ID / timestamp overlay |
| **ABR** | Automatic quality switching by buffer health |
| **Token refresh** | Auto-refresh signed URLs before expiry |
| **Sleep timer** | Countdown with fade-out |
| **Device** | Volume, brightness, battery, wakelock, secure mode, HDR |

---

## Installation

```yaml
dependencies:
  senzu_player: ^1.0.0
```

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

In **Xcode → Signing & Capabilities**, add:
- **Background Modes** → ✅ Audio, AirPlay, and Picture in Picture

Minimum deployment target: **iOS 14.0**

### Android

In `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>

<activity
  ...
  android:supportsPictureInPicture="true"
  android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation">
```

Minimum SDK: **21**

---

## Quick Start

```dart
import 'package:senzu_player/senzu_player.dart';

SenzuPlayer(
  source: {
    '1080p': VideoSource.fromUrl('https://example.com/video.m3u8'),
    '720p':  VideoSource.fromUrl('https://example.com/video_720.m3u8'),
  },
  autoPlay: true,
  looping: false,
  defaultAspectRatio: 16 / 9,
)
```

### Auto-detect qualities from a master playlist

```dart
final sources = await VideoSource.fromM3u8PlaylistUrl(
  'https://example.com/master.m3u8',
  autoSubtitle: true,
);

SenzuPlayer(source: sources)
```

---

## Usage Examples

### DRM (FairPlay / Widevine)

```dart
VideoSource.fromUrl(
  'https://example.com/protected.m3u8',
  drm: SenzuDrmConfig.fairPlay(
    licenseUrl: 'https://license.example.com/fps',
    certificateUrl: 'https://license.example.com/cert',
    headers: {'Authorization': 'Bearer TOKEN'},
  ),
)
```

```dart
VideoSource.fromUrl(
  'https://example.com/protected.mpd',
  drm: SenzuDrmConfig.widevine(
    licenseUrl: 'https://license.example.com/widevine',
    headers: {'X-Custom-Header': 'value'},
  ),
)
```

### Subtitles

```dart
VideoSource.fromUrl(
  'https://example.com/video.m3u8',
  subtitle: {
    'English': SenzuPlayerSubtitle.network('https://example.com/en.vtt'),
    'Korean':  SenzuPlayerSubtitle.network('https://example.com/ko.vtt'),
  },
  initialSubtitle: 'English',
)
```

### Chapters & Skip Buttons

```dart
SenzuPlayer(
  source: sources,
  chapters: SenzuChapter.fromSkipRanges(
    opStart: Duration(seconds: 90),
    opEnd:   Duration(seconds: 180),
    edStart: Duration(minutes: 22),
    edEnd:   Duration(minutes: 23, seconds: 30),
  ),
)
```

Or define chapters manually:

```dart
chapters: [
  SenzuChapter(startMs: 0,       title: 'Intro'),
  SenzuChapter(startMs: 90000,   title: 'OP',  isSkippable: true, skipToMs: 180000),
  SenzuChapter(startMs: 180000,  title: 'Act 1'),
  SenzuChapter(startMs: 1320000, title: 'ED',  isSkippable: true, skipToMs: 1410000),
],
```

### Inline Ads

```dart
VideoSource.fromUrl(
  'https://example.com/video.m3u8',
  ads: [
    SenzuPlayerAd(
      child: MyAdWidget(),
      fractionToStart: 0.1,   // 10% into the video
      durationToSkip: Duration(seconds: 5),
      deepLink: 'https://advertiser.example.com',
    ),
  ],
)
```

### IMA SDK (VAST/VMAP)

```dart
SenzuPlayer(
  source: sources,
  imaAdTagUrl: 'https://pubads.g.doubleclick.net/gampad/ads?...',
)
```

### Live Stream

```dart
SenzuPlayer(
  source: {'Live': VideoSource.fromUrl('https://example.com/live.m3u8')},
  isLive: true,
)
```

### Low-Latency Live

```dart
VideoSource.fromUrl(
  'https://example.com/ll-hls.m3u8',
  isLowLatency: true,
  targetLatencyMs: 2000,
)
```

### Watermark

```dart
SenzuPlayer(
  source: sources,
  watermark: SenzuWatermark(
    userId: 'user_12345',
    position: WatermarkPosition.random,
    moveDuration: Duration(seconds: 30),
  ),
)
```

### Token Auto-Refresh

```dart
SenzuPlayer(
  source: sources,
  tokenConfig: SenzuTokenConfig(
    refreshBeforeExpirySec: 60,
    onRefresh: (sourceName, currentHeaders) async {
      final data = await myApi.refreshSignedUrl(sourceName);
      return {'url': data.url, 'Authorization': 'Bearer ${data.token}'};
    },
  ),
)
```

### Timed Annotations

```dart
SenzuPlayer(
  source: sources,
  annotations: [
    SenzuAnnotation(
      id: 'subscribe',
      text: '👍 Subscribe!',
      appearAt:    Duration(seconds: 30),
      disappearAt: Duration(seconds: 35),
      alignment: Alignment.topRight,
      onTap: () => openSubscribePage(),
    ),
  ],
)
```

### Cellular Data Policy

```dart
SenzuPlayer(
  source: sources,
  dataPolicy: SenzuDataPolicy(
    warnOnCellular: true,
    dataSaverOnCellular: true,
    dataSaverQualityKey: '480p',
  ),
)
```

### Sleep Timer

Accessible via the clock icon in the top overlay — no extra code needed.

---

## Advanced: External Bundle

For full programmatic control, create and manage the bundle yourself:

```dart
final bundle = SenzuPlayerBundle.create(
  looping: false,
  adaptiveBitrate: true,
  notification: true,
  watermark: SenzuWatermark(userId: 'user_123'),
);

await bundle.core.initialize(sources, autoPlay: true);

// Seek, speed, quality...
await bundle.core.seekTo(Duration(minutes: 5));
await bundle.core.setPlaybackSpeed(1.5);
bundle.core.changeSource(name: '720p', source: sources['720p']!);

// Always dispose
bundle.dispose();
```

Pass it to the widget:

```dart
SenzuPlayer(
  source: sources,
  bundle: bundle,   // widget won't own/dispose it
)
```

---

## Customization

### Style

```dart
SenzuPlayer(
  source: sources,
  style: SenzuPlayerStyle(
    progressBarStyle: SenzuProgressBarStyle(
      color: Colors.blue,
      height: 3.0,
    ),
    centerButtonStyle: SenzuCenterButtonStyle(
      circleSize: 56,
      circleColor: Colors.black54,
    ),
    thumbnail: Image.network('https://example.com/thumb.jpg', fit: BoxFit.cover),
    onNextEpisode: () => goToNext(),
    onPrevEpisode: () => goToPrev(),
    hasPrevEpisode: currentIndex > 0,
    hasNextEpisode: currentIndex < total - 1,
  ),
)
```

### Localization

```dart
SenzuPlayerStyle(
  senzuLanguage: SenzuLanguage(
    quality: '화질',
    speed: '배속',
    subtitle: '자막',
    live: '라이브',
    skipOp: 'OP 건너뛰기',
    skipAd: '광고 건너뛰기',
    // ... all strings customizable
  ),
)
```

---

## Feature Flags

```dart
SenzuPlayer(
  source: sources,
  enableFullscreen: true,
  enableCaption:    true,
  enableQuality:    true,
  enableAudio:      false,
  enableSpeed:      true,
  enableAspect:     true,
  enableLock:       true,
  enablePip:        true,
  enableEpisode:    false,
  notification:     true,
  secureMode:       false,
  adaptiveBitrate:  true,
)
```

---

## Architecture

```
SenzuPlayerBundle
├── SenzuCoreController       # Source management, native bridge, lifecycle
├── SenzuPlaybackController   # Position, duration, buffering, drag
├── SenzuUIController         # Overlay, panels, chapters, skip buttons
├── SenzuSubtitleController   # VTT/SRT parsing, O(log n) lookup
├── SenzuAdController         # Inline ads, IMA SDK
├── SenzuStreamController     # ABR, live edge / DVR tracking
├── SenzuDeviceController     # Volume, brightness, battery
├── SenzuSleepTimerController # Countdown + fade animation
└── SenzuAnnotationController # Timed annotation overlay

Native Layer
├── iOS:     SenzuAVPlayerManager, SenzuDrmManager (FairPlay), SenzuSurfaceViewFactory
└── Android: SenzuExoPlayerManager, SenzuDrmManager (Widevine), SenzuMediaSessionManager, SenzuPipManager
```

---

## Requirements

| Platform | Minimum |
|---|---|
| iOS | 14.0 |
| Android | API 21 (Lollipop) |
| Flutter | 3.41.0 |
| Dart | 3.8.0 |

---

## License

MIT — see [LICENSE](LICENSE)

---

## Contributing

Issues and pull requests are welcome at [github.com/kenji-07/senzu_player](https://github.com/kenji-07/senzu_player).