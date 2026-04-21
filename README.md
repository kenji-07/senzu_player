# senzu_player

A powerful, feature-rich Flutter video player plugin built on top of **AVPlayer** (iOS) and **ExoPlayer / Media3** (Android).

[![pub version](https://img.shields.io/pub/v/senzu_player.svg)](https://pub.dev/packages/senzu_player)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-blue)](https://pub.dev/packages/senzu_player)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Features

| Feature | iOS | Android |
|---|---|---|
| HLS / DASH / MP4 | ✅ | ✅ |
| FairPlay DRM | ✅ | — |
| Widevine DRM | — | ✅ |
| Picture-in-Picture | ✅ | ✅ (API 26+) |
| Now Playing / Lock Screen | ✅ | ✅ |
| Google Cast (Chromecast) | ✅ | ✅ |
| HDR playback | ✅ | ✅ |
| Low-latency live | ✅ | ✅ |
| Adaptive Bitrate (ABR) | ✅ | ✅ |
| Audio track selection | ✅ | ✅ |
| Subtitles (WebVTT / SRT) | ✅ | ✅ |
| Encrypted subtitles (AES) | ✅ | ✅ |
| Chapters & skip OP/ED | ✅ | ✅ |
| Annotations overlay | ✅ | ✅ |
| Watermark overlay | ✅ | ✅ |
| Sleep timer | ✅ | ✅ |
| Token / signed URL refresh | ✅ | ✅ |
| Cellular data warning | ✅ | ✅ |
| Thumbnail sprite preview | ✅ | ✅ |
| Fullscreen overlay | ✅ | ✅ |
| Secure mode (screenshot block) | ✅ | ✅ |
| Volume / brightness gesture | ✅ | ✅ |
| Long-press 2× speed | ✅ | ✅ |

---

## Installation

```yaml
dependencies:
  senzu_player: ^1.0.0
```

### iOS

Minimum iOS version: **14.0**

Add the following to your `Info.plist`:

```xml
<!-- Background audio -->
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>

<!-- Allow HTTP (if needed) -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

Add to `Podfile`:

```ruby
platform :ios, '14.0'
```

### Android

Minimum SDK: **21**

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />

<!-- Inside <application> — required for Google Cast -->
<meta-data
    android:name="com.google.android.gms.cast.framework.OPTIONS_PROVIDER_CLASS_NAME"
    android:value="dev.senzu.senzu_player.SenzuCastOptionsProvider" />
```

Add to `android/app/build.gradle`:

```

coreLibraryDesugaringEnabled true
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'
}
```

---

## Basic Usage

```dart
import 'package:senzu_player/senzu_player.dart';

SenzuPlayer(
  source: {
    'Auto': VideoSource.fromUrl('https://example.com/stream.m3u8'),
  },
)
```

### Multiple quality sources

```dart
SenzuPlayer(
  source: {
    '1080p': VideoSource.fromUrl('https://example.com/1080p.m3u8'),
    '720p':  VideoSource.fromUrl('https://example.com/720p.m3u8'),
    '480p':  VideoSource.fromUrl('https://example.com/480p.m3u8'),
  },
  defaultAspectRatio: 16 / 9,
)
```

### Auto-parse quality from M3U8 playlist

```dart
final sources = await VideoSource.fromM3u8PlaylistUrl(
  'https://example.com/master.m3u8',
  autoSubtitle: true,
);

SenzuPlayer(source: sources)
```

---

## Advanced Usage

### DRM

**FairPlay (iOS)**

```dart
VideoSource.fromUrl(
  'https://example.com/stream.m3u8',
  drm: SenzuDrmConfig.fairPlay(
    licenseUrl:     'https://license.example.com/fps',
    certificateUrl: 'https://license.example.com/cert',
    headers: {'Authorization': 'Bearer token'},
  ),
)
```

**Widevine (Android)**

```dart
VideoSource.fromDashUrl(
  'https://example.com/stream.mpd',
  drm: SenzuDrmConfig.widevine(
    licenseUrl: 'https://license.example.com/widevine',
    headers: {'Authorization': 'Bearer token'},
  ),
)
```

---

### Subtitles

```dart
VideoSource.fromUrl(
  'https://example.com/stream.m3u8',
  subtitle: {
    'English': SenzuPlayerSubtitle.network(
      'https://example.com/en.vtt',
    ),
    'Mongolian': SenzuPlayerSubtitle.network(
      'https://example.com/mn.vtt',
    ),
  },
  initialSubtitle: 'English',
)
```

---

### Chapters (Skip OP / ED)

```dart
SenzuPlayer(
  source: sources,
  chapters: SenzuChapter.fromSkipRanges(
    opStart: const Duration(seconds: 5),
    opEnd:   const Duration(seconds: 95),
    edStart: const Duration(minutes: 22),
    edEnd:   const Duration(minutes: 23, seconds: 30),
  ),
)
```

Or define chapters manually:

```dart
chapters: [
  SenzuChapter(startMs: 0,       title: 'Intro',    isSkippable: false),
  SenzuChapter(startMs: 5000,    title: 'OP',       isSkippable: true, skipToMs: 95000),
  SenzuChapter(startMs: 95000,   title: 'Episode'),
  SenzuChapter(startMs: 1320000, title: 'ED',       isSkippable: true, skipToMs: 1410000),
]
```

---

### Google Cast (Chromecast)

```dart
// 1. Create controller
final castController = SenzuCastController();

// 2. Pass to SenzuPlayer
SenzuPlayer(
  source: sources,
  castController: castController,
  meta: SenzuMetaData(
    title: 'My Video',
    description: 'Episode 1',
  ),
)
```

The cast button appears automatically in the top controls. Tapping it opens a device picker panel. Once connected, playback transfers seamlessly to the Chromecast receiver and returns to local playback when disconnected.

**Custom cast media**

```dart
await castController.switchToCast(
  media: SenzuCastMedia(
    url:         'https://example.com/stream.m3u8',
    title:       'My Video',
    description: 'Episode 1',
    posterUrl:   'https://example.com/poster.jpg',
    positionMs:  30000,
    availableSubtitles: [
      CastSubtitleTrack(id: 1001, language: 'en', name: 'English', url: 'https://example.com/en.vtt'),
    ],
    availableQualities: [
      CastQualityOption(label: '1080p', url: 'https://example.com/1080p.m3u8'),
      CastQualityOption(label: '720p',  url: 'https://example.com/720p.m3u8'),
    ],
  ),
  currentPosition: Duration(seconds: 30),
);
```

---

### Watermark

```dart
SenzuPlayer(
  source: sources,
  watermark: SenzuWatermark(
    userId:        'user_123',
    showTimestamp: true,
    opacity:       0.18,
    position:      WatermarkPosition.random,
    moveDuration:  Duration(seconds: 30),
  ),
)
```

---

### Annotations

```dart
SenzuPlayer(
  source: sources,
  annotations: [
    SenzuAnnotation(
      id:          'promo_1',
      text:        '🎁 Special offer!',
      appearAt:    Duration(seconds: 30),
      disappearAt: Duration(seconds: 40),
      alignment:   Alignment.topRight,
      onTap:       () => launchUrl(Uri.parse('https://example.com')),
    ),
  ],
)
```

---

### Sleep Timer

```dart
// Start a 30-minute sleep timer
bundle.sleepTimer.start(Duration(minutes: 30));

// Cancel
bundle.sleepTimer.stop();
```

---

### Token / Signed URL Refresh

```dart
SenzuPlayer(
  source: sources,
  tokenConfig: SenzuTokenConfig(
    refreshBeforeExpirySec: 60,
    onRefresh: (sourceName, headers) async {
      final newUrl = await myApi.refreshSignedUrl(sourceName);
      return {'url': newUrl, 'Authorization': 'Bearer newtoken'};
    },
  ),
)
```

---

### Thumbnail Sprite Preview

```dart
VideoSource.fromUrl(
  'https://example.com/stream.m3u8',
  thumbnailSprite: SenzuThumbnailSprite(
    url:         'https://example.com/thumbnails.jpg',
    columns:     10,
    rows:        10,
    intervalSec: 10,
  ),
)
```

---

### Cellular Data Policy

```dart
SenzuPlayer(
  source: sources,
  dataPolicy: SenzuDataPolicy(
    warnOnCellular:      true,
    dataSaverOnCellular: true,
    dataSaverQualityKey: '480p',
  ),
)
```

---

### Controlling playback externally

```dart
// Create and hold the bundle
final bundle = SenzuPlayerBundle.create();

SenzuPlayer(
  source: sources,
  bundle: bundle,
)

// Control from outside
bundle.core.play();
bundle.core.pause();
bundle.core.seekTo(Duration(minutes: 5));
bundle.core.setPlaybackSpeed(1.5);
```

---

### Localization

```dart
SenzuPlayer(
  source: sources,
  style: SenzuPlayerStyle(
    senzuLanguage: SenzuLanguage(
      live:               'ШУУД',
      quality:            'Чанар',
      subtitles:          'Хадмал',
      playbackSpeed:      'Тоглуулах хурд',
      sleepTimer:         'Унтах цаг',
      failedToLoad:       'Видео ачааллахад алдаа гарлаа',
      retry:              'Дахин оролдох',
      cellularWarningTitle: 'Мобайл дата ашиглаж байна',
      cellularWarningBody:  'Видео стриминг мобайл дата зарцуулна.',
    ),
  ),
)
```

---

## SenzuPlayer Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `source` | `Map<String, VideoSource>` | required | Video sources by quality label |
| `seekTo` | `Duration` | `Duration.zero` | Initial seek position |
| `looping` | `bool` | `false` | Loop playback |
| `autoPlay` | `bool` | `true` | Auto-start playback |
| `isLive` | `bool?` | `null` | Force live stream mode |
| `style` | `SenzuPlayerStyle?` | default | UI style configuration |
| `meta` | `SenzuMetaData?` | default | Title/description metadata |
| `chapters` | `List<SenzuChapter>` | `[]` | Chapter markers |
| `annotations` | `List<SenzuAnnotation>` | `[]` | Tappable overlay annotations |
| `watermark` | `SenzuWatermark?` | `null` | Floating watermark |
| `defaultAspectRatio` | `double` | `16/9` | Player aspect ratio |
| `enableFullscreen` | `bool` | `true` | Fullscreen button |
| `enableCaption` | `bool` | `true` | Subtitle panel |
| `enableQuality` | `bool` | `true` | Quality panel |
| `enableAudio` | `bool` | `false` | Audio track panel |
| `enableSpeed` | `bool` | `true` | Playback speed panel |
| `enableAspect` | `bool` | `true` | Aspect ratio panel |
| `enableLock` | `bool` | `true` | Screen lock button |
| `enablePip` | `bool` | `true` | Picture-in-Picture |
| `enableSleep` | `bool` | `true` | Sleep timer panel |
| `enableEpisode` | `bool` | `true` | Episode panel |
| `notification` | `bool` | `true` | Lock screen / Now Playing |
| `secureMode` | `bool` | `false` | Block screenshots |
| `adaptiveBitrate` | `bool` | `true` | Auto quality switching |
| `dataPolicy` | `SenzuDataPolicy` | default | Cellular data behavior |
| `tokenConfig` | `SenzuTokenConfig?` | `null` | Signed URL auto-refresh |
| `imaAdTagUrl` | `String?` | `null` | Google IMA VAST ad tag URL |
| `castController` | `SenzuCastController?` | `null` | Google Cast controller |
| `bundle` | `SenzuPlayerBundle?` | `null` | External controller bundle |

---

## Requirements

| Platform | Minimum version |
|---|---|
| iOS | 14.0 |
| Android | API 21 (Android 5.0) |
| Flutter | 3.x |
| Dart | 3.x |

---

## License

MIT License — see [LICENSE](LICENSE) for details.